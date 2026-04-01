#include "nexrad/level2_parser.h"
#include "nexrad/products.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <limits>
#include <string>
#include <vector>

namespace {

constexpr int kNumProducts = (int)Product::COUNT;

using Clock = std::chrono::steady_clock;

float elapsedMs(Clock::time_point start, Clock::time_point end) {
    return std::chrono::duration<float, std::milli>(end - start).count();
}

uint64_t fnv1aAppend(uint64_t hash, const void* data, size_t len) {
    const auto* bytes = static_cast<const uint8_t*>(data);
    for (size_t i = 0; i < len; ++i) {
        hash ^= uint64_t(bytes[i]);
        hash *= 1099511628211ull;
    }
    return hash;
}

uint64_t fnv1aAppendString(uint64_t hash, const std::string& value) {
    hash = fnv1aAppend(hash, value.data(), value.size());
    const uint8_t terminator = 0xff;
    return fnv1aAppend(hash, &terminator, 1);
}

uint64_t fnv1aAppendFloat(uint64_t hash, float value) {
    uint32_t bits = 0;
    std::memcpy(&bits, &value, sizeof(bits));
    return fnv1aAppend(hash, &bits, sizeof(bits));
}

struct ProbeProductData {
    bool has_data = false;
    int num_gates = 0;
    float first_gate_km = 0.0f;
    float gate_spacing_km = 0.0f;
    float scale = 0.0f;
    float offset = 0.0f;
    std::vector<uint16_t> gates;
};

struct ProbeSweep {
    float elevation_angle = 0.0f;
    int num_radials = 0;
    std::vector<float> azimuths;
    ProbeProductData products[kNumProducts];
};

ProbeSweep buildPrecomputedSweep(const ParsedSweep& sweep) {
    ProbeSweep pc;
    pc.elevation_angle = sweep.elevation_angle;
    pc.num_radials = (int)sweep.radials.size();
    if (pc.num_radials == 0)
        return pc;

    pc.azimuths.resize(pc.num_radials);
    for (int r = 0; r < pc.num_radials; ++r)
        pc.azimuths[r] = sweep.radials[r].azimuth;

    for (const auto& radial : sweep.radials) {
        for (const auto& moment : radial.moments) {
            const int product = moment.product_index;
            if (product < 0 || product >= kNumProducts)
                continue;
            auto& pd = pc.products[product];
            if (!pd.has_data || moment.num_gates > pd.num_gates) {
                pd.has_data = true;
                pd.num_gates = moment.num_gates;
                pd.first_gate_km = moment.first_gate_m / 1000.0f;
                pd.gate_spacing_km = moment.gate_spacing_m / 1000.0f;
                pd.scale = moment.scale;
                pd.offset = moment.offset;
            }
        }
    }

    for (int product = 0; product < kNumProducts; ++product) {
        auto& pd = pc.products[product];
        if (!pd.has_data || pd.num_gates <= 0)
            continue;

        const int ng = pd.num_gates;
        const int nr = pc.num_radials;
        pd.gates.assign((size_t)ng * (size_t)nr, 0);
        for (int r = 0; r < nr; ++r) {
            for (const auto& moment : sweep.radials[r].moments) {
                if (moment.product_index != product)
                    continue;
                const int gateCount = std::min((int)moment.gates.size(), ng);
                for (int g = 0; g < gateCount; ++g)
                    pd.gates[(size_t)g * (size_t)nr + (size_t)r] = moment.gates[g];
                break;
            }
        }
    }

    return pc;
}

std::vector<ProbeSweep> buildPrecomputedSweeps(const ParsedRadarData& parsed) {
    std::vector<ProbeSweep> sweeps;
    sweeps.reserve(parsed.sweeps.size());
    for (const auto& sweep : parsed.sweeps)
        sweeps.push_back(buildPrecomputedSweep(sweep));
    return sweeps;
}

uint64_t hashSweep(const ProbeSweep& sweep) {
    uint64_t hash = 1469598103934665603ull;
    hash = fnv1aAppendFloat(hash, sweep.elevation_angle);
    hash = fnv1aAppend(hash, &sweep.num_radials, sizeof(sweep.num_radials));

    const uint32_t azCount = (uint32_t)sweep.azimuths.size();
    hash = fnv1aAppend(hash, &azCount, sizeof(azCount));
    for (float azimuth : sweep.azimuths)
        hash = fnv1aAppendFloat(hash, azimuth);

    for (int product = 0; product < kNumProducts; ++product) {
        const auto& pd = sweep.products[product];
        const uint8_t hasData = pd.has_data ? 1 : 0;
        hash = fnv1aAppend(hash, &hasData, sizeof(hasData));
        hash = fnv1aAppend(hash, &pd.num_gates, sizeof(pd.num_gates));
        hash = fnv1aAppendFloat(hash, pd.first_gate_km);
        hash = fnv1aAppendFloat(hash, pd.gate_spacing_km);
        hash = fnv1aAppendFloat(hash, pd.scale);
        hash = fnv1aAppendFloat(hash, pd.offset);
        if (!pd.gates.empty())
            hash = fnv1aAppend(hash, pd.gates.data(), pd.gates.size() * sizeof(uint16_t));
    }
    return hash;
}

std::string escapeJson(const std::string& input) {
    std::string output;
    output.reserve(input.size() + 8);
    for (char c : input) {
        switch (c) {
            case '\\': output += "\\\\"; break;
            case '"': output += "\\\""; break;
            case '\n': output += "\\n"; break;
            case '\r': output += "\\r"; break;
            case '\t': output += "\\t"; break;
            default: output += c; break;
        }
    }
    return output;
}

bool readFile(const std::string& path, std::vector<uint8_t>& out) {
    std::ifstream file(path, std::ios::binary);
    if (!file)
        return false;
    file.seekg(0, std::ios::end);
    const auto size = file.tellg();
    file.seekg(0, std::ios::beg);
    if (size <= 0)
        return false;
    out.resize((size_t)size);
    file.read(reinterpret_cast<char*>(out.data()), size);
    return file.good();
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s /path/to/level2-archive\n", argv[0]);
        return 2;
    }

    std::vector<uint8_t> fileData;
    if (!readFile(argv[1], fileData)) {
        std::fprintf(stderr, "failed to read %s\n", argv[1]);
        return 1;
    }

    auto decodeStart = Clock::now();
    std::vector<uint8_t> decoded = Level2Parser::decodeArchiveBytes(fileData);
    const float decodeMs = elapsedMs(decodeStart, Clock::now());

    auto parseStart = Clock::now();
    ParsedRadarData parsed = Level2Parser::parseDecodedMessages(decoded);
    const float parseMs = elapsedMs(parseStart, Clock::now());

    auto buildStart = Clock::now();
    std::vector<ProbeSweep> sweeps = buildPrecomputedSweeps(parsed);
    const float buildMs = elapsedMs(buildStart, Clock::now());

    uint64_t decodedHash = 1469598103934665603ull;
    if (!decoded.empty())
        decodedHash = fnv1aAppend(decodedHash, decoded.data(), decoded.size());

    int lowestIdx = -1;
    float lowestElev = std::numeric_limits<float>::max();
    for (int i = 0; i < (int)sweeps.size(); ++i) {
        if (sweeps[i].num_radials <= 0)
            continue;
        if (lowestIdx < 0 || sweeps[i].elevation_angle < lowestElev) {
            lowestIdx = i;
            lowestElev = sweeps[i].elevation_angle;
        }
    }

    std::printf("{\n");
    std::printf("  \"station_id\": \"%s\",\n", escapeJson(parsed.station_id).c_str());
    std::printf("  \"station_lat\": %.6f,\n", parsed.station_lat);
    std::printf("  \"station_lon\": %.6f,\n", parsed.station_lon);
    std::printf("  \"decoded_bytes\": %zu,\n", decoded.size());
    std::printf("  \"decoded_hash\": \"%016llx\",\n", (unsigned long long)decodedHash);
    std::printf("  \"decode_ms\": %.3f,\n", decodeMs);
    std::printf("  \"parse_ms\": %.3f,\n", parseMs);
    std::printf("  \"sweep_build_ms\": %.3f,\n", buildMs);
    std::printf("  \"sweep_count\": %zu,\n", sweeps.size());
    std::printf("  \"lowest_sweep_index\": %d,\n", lowestIdx);
    std::printf("  \"lowest_sweep_elevation\": %.3f,\n", lowestIdx >= 0 ? sweeps[lowestIdx].elevation_angle : 0.0f);
    std::printf("  \"sweeps\": [\n");
    for (size_t i = 0; i < sweeps.size(); ++i) {
        const auto& sweep = sweeps[i];
        std::printf("    {\n");
        std::printf("      \"index\": %zu,\n", i);
        std::printf("      \"elevation\": %.3f,\n", sweep.elevation_angle);
        std::printf("      \"num_radials\": %d,\n", sweep.num_radials);
        std::printf("      \"hash\": \"%016llx\",\n", (unsigned long long)hashSweep(sweep));
        std::printf("      \"products\": [");
        for (int product = 0; product < kNumProducts; ++product) {
            const auto& pd = sweep.products[product];
            std::printf("%s{\"product\": %d, \"has_data\": %s, \"num_gates\": %d}",
                        product == 0 ? "" : ", ",
                        product,
                        pd.has_data ? "true" : "false",
                        pd.num_gates);
        }
        std::printf("]\n");
        std::printf("    }%s\n", i + 1 == sweeps.size() ? "" : ",");
    }
    std::printf("  ]\n");
    std::printf("}\n");
    return 0;
}
