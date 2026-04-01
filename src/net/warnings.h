#pragma once
#include <vector>
#include <string>
#include <mutex>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <thread>
#include <unordered_map>
#include <unordered_set>

enum class WarningGroup {
    Tornado,
    Severe,
    Fire,
    Flood,
    Marine,
    Watch,
    Statement,
    Advisory,
    Other
};

struct WarningPolygon {
    std::string id;
    std::string event;
    std::string headline;
    std::string office;
    std::string status;
    std::string source;
    std::string issue_time;
    std::string expire_time;
    std::vector<float> lats;
    std::vector<float> lons;
    uint32_t color = 0;
    float line_width = 2.0f;
    bool historic = false;
    bool emergency = false;
    WarningGroup group = WarningGroup::Other;
};

struct WarningRenderOptions {
    bool enabled = true;
    bool showWarnings = true;
    bool showWatches = false;
    bool showStatements = false;
    bool showAdvisories = false;
    bool showOther = false;
    bool showTornado = true;
    bool showSevere = true;
    bool showFire = false;
    bool showFlood = true;
    bool showMarine = false;
    bool showSpecialWeatherStatements = false;
    bool fillPolygons = false;
    bool outlinePolygons = true;
    float fillOpacity = 0.24f;
    float outlineScale = 1.0f;
    uint32_t tornadoColor = 0xFF4848EBu;
    uint32_t severeColor = 0xFF2EA4FFu;
    uint32_t fireColor = 0xFF4A79FFu;
    uint32_t floodColor = 0xFF6CD65Cu;
    uint32_t marineColor = 0xFFFFBE58u;
    uint32_t watchColor = 0xFF4AD6FFu;
    uint32_t statementColor = 0xFFFFB070u;
    uint32_t advisoryColor = 0xFFC2D64Cu;
    uint32_t otherColor = 0xFFB8B8B8u;

    bool allows(const WarningPolygon& warning) const;
    uint32_t resolvedColor(const WarningPolygon& warning) const;
    uint32_t resolvedFillColor(const WarningPolygon& warning) const;
    float resolvedLineWidth(const WarningPolygon& warning) const;
};

class WarningFetcher {
public:
    ~WarningFetcher();

    void startPolling();
    void stop();

    std::vector<WarningPolygon> getWarnings() const;
    void clearHistoric();
    void requestHistoricSnapshot(const std::string& isoTimestamp);
    std::vector<WarningPolygon> getHistoricWarnings(const std::string& isoTimestamp) const;

private:
    void fetchLiveOnce();
    void fetchHistoricSnapshotWorker(std::string isoTimestamp);

    std::vector<WarningPolygon> m_warnings;
    std::unordered_map<std::string, std::vector<WarningPolygon>> m_historicWarnings;
    std::unordered_map<std::string, std::vector<WarningPolygon>> m_historicWatchDays;
    std::unordered_set<std::string> m_historicInFlight;
    mutable std::mutex m_mutex;
    std::atomic<bool> m_running{false};
    std::mutex m_pollMutex;
    std::condition_variable m_pollCv;
    std::thread m_thread;
    std::mutex m_historicThreadMutex;
    std::vector<std::thread> m_historicThreads;
};
