abstract final class AppStrings {
  static const String appName = 'Roulette Lab';
  static const String offline = 'Offline';
  static const String dashboard = 'Dashboard';
  static const String analysis = 'Analyse';
  static const String performance = 'Modelprestatie';
  static const String performanceCompact = 'Scores';
  static const String settings = 'Instellingen';
  static const String settingsCompact = 'Opties';
  static const String input = 'Invoeren';
  static const String analyze = 'Analyseren';
  static const String history = 'Historie';
  static const String noHistory = 'Nog geen draaien ingevoerd.';
  static const String undo = 'Ongedaan maken';
  static const String edit = 'Bewerken';
  static const String delete = 'Verwijderen';
  static const String cancel = 'Annuleren';
  static const String save = 'Opslaan';
  static const String close = 'Sluiten';
  static const String confirm = 'Bevestigen';
  static const String loading = 'Lokale gegevens laden…';
  static const String retry = 'Opnieuw proberen';
  static const String predictNext = 'Voorspel volgende draai';
  static const String predicting = 'Modellen rekenen lokaal…';
  static const String recentDistribution = 'Recente verdeling';
  static const String baseStatistics = 'Basisstatistiek';
  static const String numberDetails = 'Getaldetails';
  static const String fullDistribution = 'Volledige verdeling';
  static const String whyThisResult = 'Waarom deze uitkomst?';
  static const String experimentalSignal = 'Experimenteel signaal';
  static const String uniformReference = 'Uniforme referentie: 1/37 ≈ 2,70%';
  static const String disclaimer =
      'Experimentele statistiek. Bij een eerlijk roulettespel zijn draaien onafhankelijk. Historische patronen geven geen winstgarantie.';
  static const String zeroHasNoDozen = '0 heeft geen dozijn.';
  static const String topNumberDozenNote =
      'Het topgetal en het dozijn met de hoogste totaalscore kunnen verschillen.';
  static const String all = 'Alles';
  static const String last30 = 'Laatste 30';
  static const String last100 = 'Laatste 100';
  static const String custom = 'Aangepast';
  static const String importData = 'Data importeren';
  static const String exportJson = 'JSON-back-up exporteren';
  static const String exportCsv = 'CSV exporteren';
  static const String dataManagement = 'Databeheer';
  static const String replaceHistory = 'Bestaande historie vervangen';
  static const String appendHistory = 'Aan historie toevoegen';
  static const String clearHistory = 'Alle historie wissen';
  static const String clearAllData = 'Alle lokale data wissen';
  static const String clearEvaluations = 'Voorspellingsevaluaties wissen';
  static const String rebuildModels = 'Modellen opnieuw opbouwen';
  static const String theme = 'Thema';
  static const String system = 'Systeem';
  static const String light = 'Licht';
  static const String dark = 'Donker';
  static const String historyOrder = 'Volgorde historie';
  static const String newestFirst = 'Nieuwste eerst';
  static const String oldestFirst = 'Oudste eerst';
  static const String analysisWindow = 'Standaard analysevenster';
  static const String recentWindows = 'Recente vensters';
  static const String animations = 'Subtiele animaties';
  static const String haptics = 'Haptische feedback op Android';
  static const String privacyOffline = 'Privacy en offline werking';
  static const String versionInfo = 'App 1.0.0 · database 1 · modellen 1';
  static const String noPrediction =
      'Maak een voorspelling om beide experimentele modellen naast elkaar te zien.';
  static const String insufficientBacktest =
      'Minimaal 21 draaien zijn nodig voor walk-forward evaluatie.';
  static const String officialPredictions = 'Officiële voorspellingen';
  static const String walkForward = 'Walk-forward backtest';
  static const String exactHit = 'Exact geraakt';
  static const String top3Hit = 'Top 3 geraakt';
  static const String dozenHit = 'Dozijn geraakt';
  static const String logLoss = 'Log-loss';
  static const String brierScore = 'Brier-score';
  static const String uniformBaseline = 'Uniforme baseline';
  static const String modelEstimate = 'Modelinschatting';
  static const String modelStrength = 'Modelsterkte';
  static const String noSelection =
      'Kies in analysemodus een getal om voorkomens en overgangen te onderzoeken.';
  static const String directSuccessors = 'Wat kwam erna?';
  static const String directPredecessors = 'Wat kwam ervoor?';
  static const String gaps = 'Tussenafstanden';
  static const String pendingSuccessor =
      'De laatste waarneming heeft nog geen opvolger.';
  static const String numberHint = 'Nummer 0–36';
  static const String invalidNumber =
      'Voer een geheel getal van 0 tot en met 36 in.';
  static const String spinAdded = 'Draai toegevoegd.';
  static const String savedLocally = 'Lokaal opgeslagen.';
  static const String operationCancelled = 'Actie geannuleerd.';
  static const String tapToAdd = 'Tik op een getal om een draai toe te voegen.';
  static const String tapForDetails =
      'Tik op een getal voor historische details.';
  static const String zero = 'Nul';
  static const String red = 'Rood';
  static const String black = 'Zwart';
  static const String even = 'Even';
  static const String odd = 'Oneven';
  static const String low = 'Laag';
  static const String high = 'Hoog';
  static const String noDozen = 'Geen dozijn';
  static const String noColumn = 'Geen kolom';
  static const String totalFallen = 'Totaal gevallen';
  static const String inWindow = 'In venster';
  static const String inAllData = 'In alle data';
  static const String lastSeen = 'Laatst gezien';
  static const String localTime = 'Lokale tijd';
  static const String notSeen = 'Nog niet gezien';
  static const String positions = 'Posities';
  static const String minimumTwoOccurrences =
      'Minimaal twee voorkomens zijn nodig.';
  static const String lastSuccessors = 'Laatste opvolgers';
  static const String wheelNeighbors = 'Wielburen ±1/±2';
  static const String noTransition = 'Nog geen overgang beschikbaar.';
  static const String top3 = 'Top 3';
  static const String veryLittleData = 'Zeer weinig data';
  static const String littleData = 'Weinig data';
  static const String moreHistoryAvailable = 'Meer historie beschikbaar';
  static const String active = 'Actief';
  static const String evaluated = 'Geëvalueerd';
  static const String topDozen = 'Topdozijn';
  static const String expertWeights = 'Expertgewichten';
  static const String currentExpertWeights = 'Huidige expertgewichten';
  static const String actualOutcome = 'Werkelijke uitkomst';
  static const String yes = 'ja';
  static const String no = 'nee';
  static const String fairBaselineDescription =
      'Eerlijke vergelijking voor 37 onafhankelijke uitkomsten';
  static const String exact = 'Exact';
  static const String top3Short = 'Top 3';
  static const String dozen = 'Dozijn';
  static const String evaluations = 'Evaluaties';
  static const String noOfficialEvaluation =
      'Nog geen officiële voorspelling geëvalueerd.';
  static const String insufficientConclusion =
      'Onvoldoende data voor een stabiele conclusie.';
  static const String betterThanUniform =
      'Tot nu toe lagere log-loss dan de uniforme baseline.';
  static const String worseThanUniform =
      'Tot nu toe hogere log-loss dan de uniforme baseline.';
  static const String europeanNumbers = 'Europese getallen 0–36';
  static const String lastSpinCount = 'Aantal laatste draaien';
  static const String windowExample = 'Bijvoorbeeld 5, 10, 20, 30';
  static const String clearPredictionQuestion =
      'Alle officiële voorspellingen en scores wissen? De draaien blijven bewaard.';
  static const String localPrivacyExplanation =
      'Alle draaien, instellingen en modelresultaten blijven in de lokale SQLite-database en voorkeuren van dit apparaat. Er zijn geen accounts, cloudservices, advertenties, telemetry of runtime-netwerkcalls.';
  static const String modelLimitationExplanation =
      'De modellen zoeken experimentele patronen, maar een eerlijk roulettewiel heeft onafhankelijke draaien. Modelinschattingen zijn geen bewezen kansen en geen inzetadvies.';
  static const String wheelModel = 'Wielafstand-patroon';
  static const String adaptiveModel = 'Adaptief ensemble';
  static const String greenLower = 'groen';
  static const String redLower = 'rood';
  static const String blackLower = 'zwart';
  static const String neutralLower = 'neutraal';
  static const String evenLower = 'even';
  static const String oddLower = 'oneven';
  static const String lowLower = 'laag';
  static const String highLower = 'hoog';
  static const String equalDirection = 'gelijk';
  static const String clockwiseDirection = 'klokwijzerzin';
  static const String counterClockwiseDirection = 'tegen de klok in';
  static const String wheelInsufficientExplanation =
      'Er is nog te weinig afstandshistorie; de verdeling blijft vrijwel uniform.';
  static const String wheelModelExplanation =
      'Vijf afstandsexperts stemmen op de volgende fysieke wielverschuiving. Recente en langere overeenkomsten wegen zwaarder.';
  static const String ensembleModelExplanation =
      'Zeven uitlegbare experts leveren elk een volledige verdeling. Hun gewichten zijn uitsluitend bijgewerkt nadat de echte volgende uitkomst bekend werd.';

  static String spinLabel(int position, int number, String color) =>
      'Draai $position: $number, $color';
  static String numberLabel(
    int number,
    String color, {
    bool selected = false,
  }) => '$number, $color${selected ? ', geselecteerd' : ''}';
  static String basedOn(int available, int requested) => available < requested
      ? 'Gebaseerd op $available beschikbare draaien'
      : 'Laatste $requested draaien';
  static String count(int value) => '$value draaien';
  static String percentage(double value) =>
      '${(value * 100).toStringAsFixed(1)}%';
  static String importSummary(int valid, int invalid) =>
      '$valid geldige en $invalid ongeldige regels gevonden.';
  static String deleteSpinQuestion(int position) =>
      'Draai $position definitief verwijderen? Afhankelijke voorspellingen worden ongeldig.';
  static String clearHistoryQuestion(int count) =>
      'Alle $count draaien wissen? Dit kan niet ongedaan worden gemaakt.';
  static String error(Object error) => 'Er ging lokaal iets mis: $error';
  static String spinTitle(int position) => 'Draai $position';
  static String editSpinTitle(int position) =>
      '$edit · ${spinTitle(position).toLowerCase()}';
  static String windowTitle(int count) => 'Laatste $count draaien';
  static String tieLabel(List<int> winners) => 'Gelijk: ${winners.join(', ')}';
  static String leaderLabel(int winner) => 'Kop: ${winner}e';
  static String dozenLabel(int dozen) => '${dozen}e dozijn';
  static String columnLabel(int column) => 'Kolom $column';
  static String lastSeenAgo(int spins) => '$spins draaien geleden';
  static String gapSummary(
    double average,
    double median,
    int minimum,
    int maximum,
  ) =>
      'Gemiddeld ${average.toStringAsFixed(1)} · mediaan ${median.toStringAsFixed(1)} · min $minimum · max $maximum';
  static String positionsLabel(Iterable<int> values) =>
      '$positions: ${values.join(', ')}';
  static String successorsLabel(Iterable<int> values) =>
      '$lastSuccessors: ${values.join(', ')}';
  static String modelVersion(int version, int spins) =>
      'Model v$version · $spins draaien';
  static String topDozenLabel(int dozen, double score) =>
      '$topDozen: ${dozen}e · ${percentage(score)}';
  static String dozenScore(int dozen, double score) =>
      '${dozen}e · ${percentage(score)}';
  static String zeroScore(double score) => '0 · ${percentage(score)}';
  static String metricPair(double? loss, double? brier) =>
      '$logLoss: ${loss?.toStringAsFixed(3)} · $brierScore: ${brier?.toStringAsFixed(3)}';
  static String resultLabel(String label, bool hit) =>
      '$label: ${hit ? yes : no}';
  static String officialSubtitle(String name) => '$name · $officialPredictions';
  static String backtestTitle(String name) => '$name · $walkForward';
  static String evaluationCount(int count) =>
      '$count strikt chronologische evaluaties';
  static String wilson(double lower, double upper) =>
      'Wilson 95%-interval exact: ${percentage(lower)}–${percentage(upper)}';
  static String rollingMetrics(double a, double b, double c) =>
      'Rolling 20/50/100 log-loss: ${a.toStringAsFixed(3)} / ${b.toStringAsFixed(3)} / ${c.toStringAsFixed(3)}';
  static String improvementSemantics(double value) =>
      'Cumulatieve log-lossverbetering ten opzichte van uniform: ${value.toStringAsFixed(3)}';
  static String issueLine(int line, String message) => 'Regel $line: $message';
  static String estimateReference(double probability) =>
      '$uniformReference · lift ${(probability * 37).toStringAsFixed(2)}×';
  static String modelDialogTitle(String model, String subject) =>
      '$model · $subject';
  static String qualityStrength(String quality) => '$quality · $modelStrength';
}
