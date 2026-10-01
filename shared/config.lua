SzCoreBenchConfig = {
    Version = '1.4.0-rc1',
    AcePermission = 'szcore.benchmark',
    HistoryLimit = 50,
    DefaultJob = 'police',
    MaxVirtualPlayers = 50000,
    MaxIterations = 1000000,
    DatabaseWriteTest = true,
    DatabaseScratchTable = 'szcore_benchmark_scratch',
    Profiles = {
        quick = { virtualPlayers = 1000, iterations = 25000, rounds = 3, dbSamples = 10 },
        full = { virtualPlayers = 10000, iterations = 100000, rounds = 5, dbSamples = 25 },
        extreme = { virtualPlayers = 25000, iterations = 250000, rounds = 5, dbSamples = 50 },
    }
}
