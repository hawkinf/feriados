import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/date_calculator_dialog.dart';
import 'widgets/pdf_export_dialog.dart';


// Versão do App
const String appVersion = '2.8.0';
const String appBuild = '22';
const String apiSource = 'BrasilAPI - https://brasilapi.com.br/api/feriados/v1/';

// === INICIALIZAÇÃO E LOCALE ===
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await initializeDateFormatting('pt_BR', null); 
  Intl.defaultLocale = 'pt_BR'; 
  runApp(const MyApp());
}

// =======================================================
// === MODELOS DE DADOS ===
// =======================================================

class Holiday {
  final String date;
  final String name;
  final List<String> types;
  final String? specialNote;

  Holiday({required this.date, required this.name, required this.types, this.specialNote});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: json['date'] as String,
      name: json['name'] as String,
      types: [(json['type'] as String).replaceAll('national', 'Nacional')],
    );
  }
  
  Holiday mergeWith(Holiday other) {
    final combinedTypes = {...types, ...other.types}.toList();
    return Holiday(
      date: date,
      name: name,
      types: combinedTypes,
      specialNote: specialNote ?? other.specialNote,
    );
  }
}

class CityData {
  final String name;
  final String state;
  final String region;
  final List<Map<String, String>> municipalHolidays;

  CityData({required this.name, required this.state, required this.region, required this.municipalHolidays});
}

class YearlyData {
  final int year;
  final int weekdayHolidays;
  YearlyData(this.year, this.weekdayHolidays);
}

class MonthStats {
  final String monthName;
  int totalDays = 0;
  int weekendDays = 0;
  MonthStats(this.monthName);
}

class HolidayStats {
  int bancarios = 0;
  int nacionais = 0;
  int estaduais = 0;
  int municipais = 0;
  int segundas = 0;
  int tercas = 0;
  int quartas = 0;
  int quintas = 0;
  int sextas = 0;
  int diasUteis = 0;
  int finaisSemana = 0;
  int totalFeriadosUnicos = 0;

  Map<int, MonthStats> monthlyStats = {}; 
  
  void addMonthStat(int month, String monthName, bool isWeekend) {
    monthlyStats.putIfAbsent(month, () => MonthStats(monthName));
    monthlyStats[month]!.totalDays++;
    if (isWeekend) {
      monthlyStats[month]!.weekendDays++;
    }
  }
}

// =======================================================
// === WIDGET PRINCIPAL ===
// =======================================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDarkMode = prefs.getBool('isDarkMode') ?? false;
      setState(() {
        _isDarkMode = savedDarkMode;
      });
    } catch (e) {
      debugPrint('Erro ao carregar tema: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feriados',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // TEMA CLARO
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2), brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: const CardThemeData(
          elevation: 0, 
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)))
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0, 
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      
      // TEMA ESCURO (CORRIGIDO PARA LEGIBILIDADE)
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2), 
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E), // Fundo dos cards mais suave
          onSurface: Colors.white, // Texto branco
        ),
        scaffoldBackgroundColor: const Color(0xFF121212), // Fundo preto suave
        cardTheme: const CardThemeData(
          elevation: 0, 
          color: Color(0xFF1E1E1E), // Card escuro
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)))
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0, 
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C), // Input field escuro
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      
      home: HolidayScreen(
        onThemeChanged: (isDark) {
          setState(() {
            _isDarkMode = isDark;
          });
        },
      ),
    );
  }
}

// =======================================================
// === TELA PRINCIPAL ===
// =======================================================

class HolidayScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const HolidayScreen({super.key, required this.onThemeChanged});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> with SingleTickerProviderStateMixin {
  int _selectedYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;
  late DateTime _selectedWeek;
  String _calendarType = 'mensal'; // 'semanal', 'mensal', 'anual'
  late CityData _selectedCity;
  late Future<List<Holiday>> _holidaysFuture;
  late AnimationController _animationController;
  bool _isLoading = true;
  bool _isDarkMode = false;

  // Cache para "Próximo Feriado"
  ({String name, int daysUntil})? _cachedNextHoliday;
  DateTime? _cachedNextHolidayDate;

  final List<int> availableYears = List.generate(11, (index) => DateTime.now().year - 5 + index);

  late final List<CityData> cities;
  
  @override
  void initState() {
    super.initState();
    _selectedWeek = DateTime.now();
    _selectedYear = DateTime.now().year;
    _calendarMonth = DateTime.now().month;
    _initializeCities();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadPreferences();
  }
  
  void _initializeCities() {
    cities = [
      // === SP E GRANDE SP ===
      CityData(name: 'São Paulo', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-01-25', 'name': 'Aniversário de São Paulo'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santo André', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-08', 'name': 'Aniversário de Santo André'}]),
      CityData(name: 'São Bernardo do Campo', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-08-20', 'name': 'Aniversário de São Bernardo'}]),
      CityData(name: 'São Caetano do Sul', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-07-28', 'name': 'Aniversário de São Caetano'}]),
      CityData(name: 'Diadema', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Diadema'}]),
      CityData(name: 'Mauá', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Mauá'}]),
      CityData(name: 'Ribeirão Pires', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Ribeirão Pires'}]),
      CityData(name: 'Rio Grande da Serra', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-05-03', 'name': 'Aniversário de Rio Grande da Serra'}]),
      CityData(name: 'Guarulhos', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Guarulhos'}]),
      CityData(name: 'Osasco', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-02-19', 'name': 'Aniversário de Osasco'}]),
      CityData(name: 'Barueri', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-03-26', 'name': 'Aniversário de Barueri'}]),
      CityData(name: 'Cotia', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-02', 'name': 'Aniversário de Cotia'}]),
      CityData(name: 'Taboão da Serra', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-02-19', 'name': 'Aniversário de Taboão'}]),
      CityData(name: 'Mogi das Cruzes', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-09-01', 'name': 'Aniversário de Mogi'}]),
      CityData(name: 'Suzano', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-02', 'name': 'Aniversário de Suzano'}]),

      // === LITORAL SUL ===
      CityData(name: 'Santos', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-26', 'name': 'Aniversário de Santos'}, {'date': '-09-08', 'name': 'Nossa Senhora do Monte Serrat'}]),
      CityData(name: 'São Vicente', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-22', 'name': 'Aniversário de São Vicente'}]),
      CityData(name: 'Guarujá', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-06-30', 'name': 'Aniversário de Guarujá'}]),
      CityData(name: 'Praia Grande', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-19', 'name': 'Aniversário de Praia Grande'}]),
      CityData(name: 'Cubatão', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-04-09', 'name': 'Aniversário de Cubatão'}]),
      CityData(name: 'Bertioga', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-05-19', 'name': 'Aniversário de Bertioga'}]),
      CityData(name: 'Mongaguá', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-12-07', 'name': 'Aniversário de Mongaguá'}]),
      CityData(name: 'Itanhaém', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-04-22', 'name': 'Aniversário de Itanhaém'}]),
      CityData(name: 'Peruíbe', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-02-18', 'name': 'Aniversário de Peruíbe'}]),

      // === VALE DO PARAÍBA ===
      CityData(name: 'Caçapava', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-14', 'name': 'Aniversário de Caçapava'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Igaratá', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-27', 'name': 'Aniversário de Igaratá'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Jacareí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-08', 'name': 'Aniversário de Jacareí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Jambeiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-24', 'name': 'Aniversário de Jambeiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Monteiro Lobato', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-24', 'name': 'Aniversário de Monteiro Lobato'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Paraibuna', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-14', 'name': 'Aniversário de Paraibuna'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santa Branca', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-04', 'name': 'Aniversário de Santa Branca'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São José dos Campos', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Dia de São José'}, {'date': '-07-27', 'name': 'Aniversário de São José dos Campos'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Campos do Jordão', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-15', 'name': 'Aniversário de Campos do Jordão'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lagoinha', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Lagoinha'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Natividade da Serra', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Natividade da Serra'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Pindamonhangaba', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-07-10', 'name': 'Aniversário de Pindamonhangaba'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Redenção da Serra', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-19', 'name': 'Aniversário de Redenção da Serra'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santo Antônio do Pinhal', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-05-13', 'name': 'Aniversário de Santo Antônio do Pinhal'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São Bento do Sapucaí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-21', 'name': 'Aniversário de São Bento do Sapucaí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São Luiz do Paraitinga', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-05-08', 'name': 'Aniversário de São Luiz do Paraitinga'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Taubaté', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-05', 'name': 'Aniversário de Taubaté'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Tremembé', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Tremembé'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Aparecida', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Aparecida'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cachoeira Paulista', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-28', 'name': 'Aniversário de Cachoeira Paulista'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Canas', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-20', 'name': 'Aniversário de Canas'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cunha', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-15', 'name': 'Aniversário de Cunha'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Guaratinguetá', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-02-13', 'name': 'Aniversário de Guaratinguetá'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lorena', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-06-24', 'name': 'Aniversário de Lorena'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Piquete', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-28', 'name': 'Aniversário de Piquete'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Potim', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Potim'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Roseira', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-27', 'name': 'Aniversário de Roseira'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Arapeí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-02-26', 'name': 'Aniversário de Arapeí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Areias', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-11-24', 'name': 'Aniversário de Areias'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Bananal', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-11-21', 'name': 'Aniversário de Bananal'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cruzeiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-10-16', 'name': 'Aniversário de Cruzeiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lavrinhas', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-19', 'name': 'Aniversário de Lavrinhas'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Queluz', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-08', 'name': 'Aniversário de Queluz'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São José do Barreiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-08-24', 'name': 'Aniversário de São José do Barreiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Silveiras', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-07-26', 'name': 'Aniversário de Silveiras'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      
      // === LITORAL NORTE ===
      CityData(name: 'Caraguatatuba', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-04-20', 'name': 'Aniversário de Caraguatatuba'}]),
      CityData(name: 'Ilhabela', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-09-03', 'name': 'Aniversário de Ilhabela'}]),
      CityData(name: 'São Sebastião', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-03-16', 'name': 'Aniversário de São Sebastião'}, {'date': '-01-20', 'name': 'Dia de São Sebastião'}]),
      CityData(name: 'Ubatuba', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-10-28', 'name': 'Aniversário de Ubatuba'}]),
      
      // === SUL DE MINAS (COM FERIADOS PREENCHIDOS) ===
      CityData(name: 'Alfenas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-15', 'name': 'Aniversário de Alfenas'}]),
      CityData(name: 'Andradas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-02-22', 'name': 'Aniversário de Andradas'}]),
      CityData(name: 'Boa Esperança', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-15', 'name': 'Aniversário de Boa Esperança'}]),
      CityData(name: 'Brazópolis', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Brazópolis'}]),
      CityData(name: 'Cambuí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-13', 'name': 'Aniversário de Cambuí'}]),
      CityData(name: 'Campanha', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-04-12', 'name': 'Feriado Padre Victor'}]),
      CityData(name: 'Campo Belo', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-28', 'name': 'Aniversário de Campo Belo'}]),
      CityData(name: 'Campos Gerais', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Campos Gerais'}]),
      CityData(name: 'Carmo de Minas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Carmo de Minas'}]),
      CityData(name: 'Caxambu', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Caxambu'}]),
      CityData(name: 'Conceição do Rio Verde', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-08-23', 'name': 'Aniversário de Conceição do Rio Verde'}]),
      CityData(name: 'Cristina', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-15', 'name': 'Aniversário de Cristina'}]),
      CityData(name: 'Extrema', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Extrema'}]),
      CityData(name: 'Guaxupé', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-06-01', 'name': 'Aniversário de Guaxupé'}]),
      CityData(name: 'Itajubá', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Itajubá'}]),
      CityData(name: 'Itamonte', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-12-17', 'name': 'Aniversário de Itamonte'}]),
      CityData(name: 'Itanhandu', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-07', 'name': 'Aniversário de Itanhandu'}]),
      CityData(name: 'Lavras', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-13', 'name': 'Aniversário de Lavras'}]),
      CityData(name: 'Maria da Fé', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-06-01', 'name': 'Aniversário de Maria da Fé'}]),
      CityData(name: 'Monte Verde (Camanducaia)', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-20', 'name': 'Aniversário de Camanducaia'}]),
      CityData(name: 'Ouro Fino', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-03-16', 'name': 'Aniversário de Ouro Fino'}]),
      CityData(name: 'Paraisópolis', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-01-25', 'name': 'Aniversário de Paraisópolis'}]),
      CityData(name: 'Passa Quatro', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-01', 'name': 'Aniversário de Passa Quatro'}]),
      CityData(name: 'Passos', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-14', 'name': 'Aniversário de Passos'}]),
      CityData(name: 'Pedralva', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-07', 'name': 'Aniversário de Pedralva'}]),
      CityData(name: 'Piumhi', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-20', 'name': 'Aniversário de Piumhi'}]),
      CityData(name: 'Poços de Caldas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-11-06', 'name': 'Aniversário de Poços de Caldas'}]),
      CityData(name: 'Pouso Alegre', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-19', 'name': 'Aniversário de Pouso Alegre'}]),
      CityData(name: 'Santa Rita do Sapucaí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-22', 'name': 'Santa Rita de Cássia'}]),
      CityData(name: 'São Gonçalo do Sapucaí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-27', 'name': 'Aniversário de São Gonçalo'}]),
      CityData(name: 'São Lourenço', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-04-01', 'name': 'Aniversário de São Lourenço'}]),
      CityData(name: 'São Sebastião do Paraíso', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-25', 'name': 'Aniversário de Paraíso'}]),
      CityData(name: 'Três Corações', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-23', 'name': 'Aniversário de Três Corações'}]),
      CityData(name: 'Três Pontas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-03', 'name': 'Aniversário de Três Pontas'}]),
      CityData(name: 'Varginha', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-07', 'name': 'Aniversário de Varginha'}]),
    ];
    
    cities.sort((a, b) => a.name.compareTo(b.name));
    
    _selectedCity = cities.firstWhere((city) => city.name == 'São José dos Campos', orElse: () => cities.first);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCityName = prefs.getString('selectedCity');
      if (savedCityName != null) {
        final cityIndex = cities.indexWhere((city) => city.name == savedCityName);
        if (cityIndex != -1) {
          _selectedCity = cities[cityIndex];
        }
      }
      // Sempre usar data atual, não carregar ano anterior
      _selectedYear = DateTime.now().year;
      _calendarMonth = DateTime.now().month;
      final savedDarkMode = prefs.getBool('isDarkMode');
      if (savedDarkMode != null) _isDarkMode = savedDarkMode;
    } catch (e) {
      debugPrint('Erro: $e');
    }
    setState(() {
      _holidaysFuture = _fetchHolidays(_selectedYear);
      _isLoading = false;
    });
    _animationController.forward();
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCity', _selectedCity.name);
      // Não salvar year pois sempre iniciamos com data atual
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  Future<List<Holiday>> _fetchHolidays(int year) async {
    Map<String, Holiday> holidaysMap = {};
    
    try {
      // Carregar feriados do ano atual
      final uriNacional = Uri.parse('https://brasilapi.com.br/api/feriados/v1/$year');
      final response = await http.get(uriNacional);
      if (response.statusCode == 200) {
        List jsonList = json.decode(response.body);
        for (var json in jsonList) {
          final holiday = Holiday.fromJson(json);
          holidaysMap[holiday.date] = holiday;
        }
      } else {
        throw Exception('Falha ao carregar feriados nacionais.');
      }
      
      // CARREGAR TAMBÉM FERIADOS DO PRÓXIMO ANO (para exibir em dezembro/janeiro)
      final nextYear = year + 1;
      final uriProximo = Uri.parse('https://brasilapi.com.br/api/feriados/v1/$nextYear');
      final responseProximo = await http.get(uriProximo);
      if (responseProximo.statusCode == 200) {
        List jsonList = json.decode(responseProximo.body);
        for (var json in jsonList) {
          final holiday = Holiday.fromJson(json);
          // Adicionar apenas feriados de janeiro e fevereiro do próximo ano
          final holidayDate = DateTime.parse(holiday.date);
          if (holidayDate.month <= 2) {
            holidaysMap[holiday.date] = holiday;
          }
        }
      }

      // Adicionar feriado bancário de último dia do ano
      final lastDay = DateTime(year, 12, 31);
      String specialNote = '';
      if (lastDay.weekday == DateTime.saturday) {
        specialNote = 'Bancos encerram às 11h na sexta-feira anterior (30/12)';
      } else if (lastDay.weekday == DateTime.sunday) {
        specialNote = 'Bancos encerram às 11h na sexta-feira anterior (29/12)';
      } else {
        specialNote = 'Bancos encerram às 11h';
      }
      final bancarioHoliday = Holiday(date: '$year-12-31', name: 'Véspera de Ano Novo', types: ['Bancário'], specialNote: specialNote);
      if (holidaysMap.containsKey(bancarioHoliday.date)) {
        holidaysMap[bancarioHoliday.date] = holidaysMap[bancarioHoliday.date]!.mergeWith(bancarioHoliday);
      } else {
        holidaysMap[bancarioHoliday.date] = bancarioHoliday;
      }
      
      // Adicionar feriados municipais do ano selecionado
      for (var holiday in _selectedCity.municipalHolidays) {
        final dateCurrentYear = '$year${holiday['date']}';
        final municipalHolidayCurrentYear = Holiday(date: dateCurrentYear, name: holiday['name']!, types: ['Municipal (${_selectedCity.name})']);
        if (holidaysMap.containsKey(dateCurrentYear)) {
          holidaysMap[dateCurrentYear] = holidaysMap[dateCurrentYear]!.mergeWith(municipalHolidayCurrentYear);
        } else {
          holidaysMap[dateCurrentYear] = municipalHolidayCurrentYear;
        }
      }
      
      final allHolidays = holidaysMap.values.toList();
      allHolidays.sort((a, b) => a.date.compareTo(b.date));
      return allHolidays;
    } catch (e) {
      throw Exception('Erro de conexão ou dados: $e');
    }
  }

  void _reloadData() {
    _savePreferences();
    setState(() {
      _holidaysFuture = _fetchHolidays(_selectedYear);
    });
    _animationController.forward(from: 0);
  }

  // --- CALCULADORA DE DATAS ---
  void _showDateCalculator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: FutureBuilder<List<Holiday>>(
          future: _fetchHolidays(_selectedYear),
          builder: (context, snapshot) {
            final holidays = snapshot.data ?? <Holiday>[];
            return DateCalculatorDialog(
              referenceDate: DateTime.now(),
              holidays: holidays,
              selectedCity: _selectedCity,
            );
          },
        ),
      ),
    );
  }

  // --- MENU SOBRE (LAYOUT RESTAURADO COM SWITCH ABAIXO DO AUTOR) ---
  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Feriados',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Versão $appVersion (Build $appBuild)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Desenvolvido por',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aguinaldo Liesack Baptistini',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // === PREFERÊNCIAS (REGIÃO E CIDADE) ===
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferências',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // BOTÃO DE MODO ESCURO (MOVIDO PARA CÁ)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Modo Escuro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _isDarkMode ? 'Ativado' : 'Desativado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    secondary: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    value: _isDarkMode,
                    onChanged: (bool value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _savePreferences();
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                const SizedBox(height: 16),

                // Fonte da API
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.api,
                        size: 32,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fonte de Dados',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BrasilAPI',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        apiSource,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('FECHAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPdfExportPreview() {
    showDialog(
      context: context,
      builder: (context) => PdfExportDialog(
        cityName: _selectedCity.name,
        calendarType: _calendarType,
        selectedYear: _selectedYear,
        selectedMonth: _calendarMonth,
        onCalendarTypeChanged: () {
          // Callback para possíveis mudanças futuras
        },
        stats: {}, // Pode passar stats se necessário
        holidays: [], // Será carregado no FutureBuilder do dialog
      ),
    );
  }

  HolidayStats _calculateStats(List<Holiday> holidays) {
    final stats = HolidayStats();
    final Map<String, Holiday> uniqueHolidaysMap = {}; // Map para manter apenas um por data

    // Primeiro, remover duplicatas por data e manter apenas uma por data
    for (var holiday in holidays) {
      if (!uniqueHolidaysMap.containsKey(holiday.date)) {
        uniqueHolidaysMap[holiday.date] = holiday;
      }
    }

    // Contar estatísticas baseado em feriados únicos
    for (var holiday in uniqueHolidaysMap.values) {
      bool isNacional = false, isEstadual = false, isMunicipal = false, isBancario = false;

      // Determinar tipos com prioridade: Nacional > Estadual > Municipal > Bancário
      for (var type in holiday.types) {
        if (type.contains('Nacional')) isNacional = true;
        if (type.contains('Estadual')) isEstadual = true;
        if (type.contains('Municipal')) isMunicipal = true;
        if (type.contains('Bancário')) isBancario = true;
      }

      // Contar por tipo (cada feriado conta uma vez, em sua categoria prioritária)
      if (isNacional) {
        stats.nacionais++;
      } else if (isEstadual) {
        stats.estaduais++;
      } else if (isMunicipal) {
        stats.municipais++;
      } else if (isBancario) {
        stats.bancarios++;
      }

      stats.totalFeriadosUnicos++;

      try {
        final date = DateFormat('yyyy-MM-dd').parse(holiday.date);
        final month = date.month;
        final monthNames = {1: 'Janeiro', 2: 'Fevereiro', 3: 'Março', 4: 'Abril', 5: 'Maio', 6: 'Junho', 7: 'Julho', 8: 'Agosto', 9: 'Setembro', 10: 'Outubro', 11: 'Novembro', 12: 'Dezembro'};
        final monthName = monthNames[month] ?? 'Mês $month';
        final isWeekend = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);
        stats.addMonthStat(month, monthName, isWeekend);
        switch (date.weekday) {
          case DateTime.monday: stats.segundas++; stats.diasUteis++; break;
          case DateTime.tuesday: stats.tercas++; stats.diasUteis++; break;
          case DateTime.wednesday: stats.quartas++; stats.diasUteis++; break;
          case DateTime.thursday: stats.quintas++; stats.diasUteis++; break;
          case DateTime.friday: stats.sextas++; stats.diasUteis++; break;
          case DateTime.saturday: case DateTime.sunday: stats.finaisSemana++; break;
        }
      } catch (e) {
        // Tratamento de erro na análise de feriado
      }
    }

    return stats;
  }

  // --- RESUMO QUE APARECE NA TELA PRINCIPAL (LIMPO E CORRIGIDO PARA DARK MODE) ---
  Widget _buildMainStatsSummary(HolidayStats stats, double fontSize) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      // Cor de fundo do card adaptativa
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESUMO DO ANO $_selectedYear', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 2, color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildStatBadge('Total de Feriados', stats.totalFeriadosUnicos, Colors.green, fontSize)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatBadge('Dias Úteis', stats.diasUteis, Colors.indigo, fontSize)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatBadge('Finais de Semana', stats.finaisSemana, Colors.red, fontSize)),
              ],
            ),
            const Divider(height: 8),
             Text('Por Tipo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            // Uso de cores dinâmicas para fundo (claro em Light, transparente em Dark) e texto (preto em Light, branco em Dark)
            _buildStatRow(context, 'Nacionais', stats.nacionais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]),
            _buildStatRow(context, 'Municipais', stats.municipais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[50]),
            _buildStatRow(context, 'Bancários', stats.bancarios, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[50]),
            _buildStatRow(context, 'Estaduais', stats.estaduais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatBadge(String label, int value, Color color, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Text(value.toString(), style: TextStyle(fontSize: fontSize + 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: fontSize - 2, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // --- MODIFICADO: _buildStatRow COM CORES DINÂMICAS ---
  Widget _buildStatRow(BuildContext context, String label, int value, Color textColor, {Color? backgroundColor}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
                // Badge de número: Cinza claro no Light, Cinza Escuro no Dark
                color: isDark ? Colors.grey[800] : Colors.grey[200], 
                borderRadius: BorderRadius.circular(8)
            ),
            child: Text(value.toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS AUXILIARES ---
  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Data inválida';
    try {
      final fullDate = DateFormat('dd \'de\' MMMM', 'pt_BR').format(date);
      final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date);
      String capitalizedDay = dayOfWeek.substring(0, 1).toUpperCase() + dayOfWeek.substring(1);
      return '$fullDate - $capitalizedDay';
    } catch (e) {
      return 'Erro de formatação';
    }
  }

  /// Calcula o próximo feriado (nacional, bancário ou municipal da cidade selecionada) a partir de hoje e retorna nome + dias restantes
  Future<({String name, int daysUntil})?> _getNextHoliday() async {
    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Verificar se o cache ainda é válido (mesmo dia)
      if (_cachedNextHoliday != null && _cachedNextHolidayDate != null) {
        final cachedDate = DateTime(_cachedNextHolidayDate!.year, _cachedNextHolidayDate!.month, _cachedNextHolidayDate!.day);
        if (cachedDate == todayDate) {
          // Cache ainda é válido
          return _cachedNextHoliday;
        }
      }

      // Cache inválido ou não existe, recalcular
      // Buscar feriados do ano atual e próximo ano para garantir que encontramos o próximo
      final currentYearHolidays = await _fetchHolidays(_selectedYear);
      final nextYearHolidays = await _fetchHolidays(_selectedYear + 1);
      final allHolidays = [...currentYearHolidays, ...nextYearHolidays];

      if (allHolidays.isEmpty) return null;

      // Encontrar o próximo feriado nacional, bancário ou municipal da cidade selecionada
      Holiday? nextHoliday;
      int minDaysDiff = 999999;

      for (final holiday in allHolidays) {
        try {
          // Filtrar apenas feriados nacionais, bancários ou municipais da cidade selecionada
          final types = holiday.types;
          final isNationalOrBancario = types.any((t) => !t.contains('Municipal'));
          final isMunicipalThisCity = types.any((t) => t.contains('Municipal') && t.contains(_selectedCity.name));

          if (!isNationalOrBancario && !isMunicipalThisCity) continue; // Pular feriados municipais de outras cidades

          final holidayDate = DateTime.parse(holiday.date);
          final normalizedHolidayDate = DateTime(holidayDate.year, holidayDate.month, holidayDate.day);

          // Calcular dias até este feriado
          int daysDiff = normalizedHolidayDate.difference(todayDate).inDays;

          // Se é hoje ou no futuro, e é o mais próximo até agora
          if (daysDiff >= 0 && daysDiff < minDaysDiff) {
            minDaysDiff = daysDiff;
            nextHoliday = holiday;
          }
        } catch (e) {
          // Ignorar datas inválidas
        }
      }

      if (nextHoliday == null) return null;

      // Atualizar cache
      final result = (name: nextHoliday.name, daysUntil: minDaysDiff);
      _cachedNextHoliday = result;
      _cachedNextHolidayDate = todayDate;

      return result;
    } catch (e) {
      debugPrint('Erro ao buscar próximo feriado: $e');
      return null;
    }
  }

  Widget _buildCalendarGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final double fontSize = isMobile ? 16.0 : 18.0;
    final double headerFontSize = isMobile ? 18.0 : 20.0;
    final double titleFontSize = (fontSize - 1) * 2.2;
    
    final now = DateTime(_selectedYear, _calendarMonth, 1);
    final firstDayOfWeek = now.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
    final daysInMonth = DateTime(_selectedYear, _calendarMonth + 1, 0).day;
    final prevMonthDays = DateTime(_selectedYear, _calendarMonth, 0).day;
    
    // Calcular mês anterior
    int prevMonth = _calendarMonth == 1 ? 12 : _calendarMonth - 1;
    int prevYear = _calendarMonth == 1 ? _selectedYear - 1 : _selectedYear;
    
    // Calcular próximo mês/ano
    int nextMonth = _calendarMonth == 12 ? 1 : _calendarMonth + 1;
    int nextYear = _calendarMonth == 12 ? _selectedYear + 1 : _selectedYear;
    
    final monthName = ['JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'][_calendarMonth - 1];
    
    final today = DateTime.now();
    final isCurrentMonth = today.year == _selectedYear && today.month == _calendarMonth;
    final todayDay = isCurrentMonth ? today.day : -1;
    
    final List<String> dayHeaders = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    List<({int day, int month, int year, bool isCurrentMonth})> calendarDays = [];
    
    // Dias do mês anterior (apenas os necessários para preencher o inicio da primeira semana)
    for (int i = prevMonthDays - firstDayOfWeek + 1; i <= prevMonthDays; i++) {
      calendarDays.add((day: i, month: prevMonth, year: prevYear, isCurrentMonth: false));
    }
    
    // Dias do mês atual
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add((day: i, month: _calendarMonth, year: _selectedYear, isCurrentMonth: true));
    }
    
    // Dias do próximo mês para completar o grid
    int remainingCells = (7 - (calendarDays.length % 7)) % 7;
    for (int i = 1; i <= remainingCells; i++) {
      calendarDays.add((day: i, month: nextMonth, year: nextYear, isCurrentMonth: false));
    }
    
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        Map<String, String> holidayNames = {};
        Set<String> holidayDays = {};
        
        debugPrint('=== Calendário Debug ===');
        debugPrint('Mês selecionado: $_calendarMonth, Ano: $_selectedYear');
        debugPrint('Mês anterior: $prevMonth/$prevYear');
        debugPrint('Próximo mês: $nextMonth/$nextYear');
        debugPrint('Dados do snapshot: ${snapshot.hasData}');
        
        if (snapshot.hasData) {
          debugPrint('Total de feriados carregados: ${snapshot.data!.length}');
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              debugPrint('Processando feriado: ${holiday.name} em ${holiday.date} (key: $key)');
              
              // Verificar se é do mês atual, anterior ou próximo
              if ((holidayDate.month == _calendarMonth && holidayDate.year == _selectedYear) ||
                  (holidayDate.month == prevMonth && holidayDate.year == prevYear) ||
                  (holidayDate.month == nextMonth && holidayDate.year == nextYear)) {
                debugPrint('✓ Feriado ADICIONADO: ${holiday.name}');
                holidayDays.add(key);
                holidayNames[key] = holiday.name;
              } else {
                debugPrint('✗ Feriado IGNORADO: ${holiday.name}');
              }
            } catch (e) {
              debugPrint('Erro ao parsear feriado: ${holiday.date} - $e');
            }
          }
          debugPrint('Total de feriados para este mês: ${holidayDays.length}');
        } else if (snapshot.hasError) {
          debugPrint('ERRO ao carregar feriados: ${snapshot.error}');
        } else {
          debugPrint('Carregando feriados...');
        }
        
        return Transform.scale(
          scale: 0.92,
          alignment: Alignment.topCenter,
          child: Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 0.15 : 0.2),
              child: Row(
              children: [
                // SETA ESQUERDA - RETROCEDEM MÊS
                SizedBox(
                  width: 50,
                  child: Center(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: isMobile ? 40 : 45,
                      icon: Icon(Icons.arrow_circle_left_rounded),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (_calendarMonth == 1) {
                            _calendarMonth = 12;
                            _selectedYear--;
                          } else {
                            _calendarMonth--;
                          }
                          _holidaysFuture = _fetchHolidays(_selectedYear);
                        });
                      },
                    ),
                  ),
                ),
                // CALENDÁRIO NO MEIO
                Expanded(
                  child: Column(
                    children: [
                      // TÍTULO DO MÊS/ANO
                      Center(
                        child: Text(
                          '$monthName / $_selectedYear',
                          style: TextStyle(fontSize: titleFontSize * 0.9, fontWeight: FontWeight.bold, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 0.5),
                      // HEADERS (DOM, SEG, TER, etc)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: dayHeaders.map((day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: headerFontSize * 0.8,
                                fontWeight: FontWeight.bold,
                                color: day == 'DOM' || day == 'SAB' ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                backgroundColor: day == 'DOM' ? Colors.red : (day == 'SAB' ? Color(0xFFEF9A9A) : Colors.transparent), // DOM vermelho escuro, SAB vermelho claro
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 0.3),
                      // GRID DO CALENDÁRIO
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.0,
                          mainAxisSpacing: 0.01,
                          crossAxisSpacing: 0.01,
                        ),
                        itemCount: calendarDays.length,
                        itemBuilder: (context, index) {
                          final dayData = calendarDays[index];
                          final day = dayData.day;
                          final month = dayData.month;
                          final year = dayData.year;
                          final isCurrentMonth = dayData.isCurrentMonth;
                          final dateObj = DateTime(year, month, day);
                          final weekday = dateObj.weekday; // 1=segunda, 7=domingo
                          final dayOfWeek = weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
                          final isToday = isCurrentMonth && day == todayDay;
                          final holidayKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                          final isHoliday = holidayDays.contains(holidayKey);
                          final holidayName = isHoliday ? holidayNames[holidayKey] : null;
                          
                          Color bgColor = Colors.white;
                          Color textColor = Theme.of(context).colorScheme.onSurface;
                          double opacity = 1.0;

                          if (isToday) {
                            bgColor = Colors.blue;
                            textColor = Colors.white;
                          } else if (isHoliday) {
                            // Feriados sempre verde com letras brancas, independente do dia da semana
                            bgColor = isCurrentMonth ? Colors.green : (Colors.lightGreen[300] ?? Colors.lightGreen);
                            textColor = isCurrentMonth ? Colors.white : (Colors.grey[700] ?? Colors.grey);
                            opacity = 1.0;
                          } else if (dayOfWeek == 0) { // Domingo
                            bgColor = Colors.red;
                            textColor = Colors.white;
                          } else if (dayOfWeek == 6) { // Sábado
                            bgColor = Color(0xFFEF9A9A); // Vermelho mais claro
                            textColor = Colors.white;
                          } else if (!isCurrentMonth) {
                            bgColor = Colors.grey[600] ?? Colors.grey;
                            opacity = 0.6;
                            textColor = Colors.white;
                          }
                          
                          return Tooltip(
                            message: holidayName ?? '',
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor.withValues(alpha: opacity),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    day.toString(),
                                    style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  if (isToday)
                                    Text(
                                      'HOJE',
                                      style: TextStyle(fontSize: (fontSize - 2) * 0.7, fontWeight: FontWeight.w600, color: textColor),
                                    ),
                                  if (isHoliday && holidayName != null)
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 0.1),
                                        child: Text(
                                          holidayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: (fontSize - 2) * 0.75, fontWeight: FontWeight.w600, color: textColor),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // SETA DIREITA - AVANÇA MÊS
                SizedBox(
                  width: 50,
                  child: Center(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: isMobile ? 40 : 45,
                      icon: Icon(Icons.arrow_circle_right_rounded),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (_calendarMonth == 12) {
                            _calendarMonth = 1;
                            _selectedYear++;
                          } else {
                            _calendarMonth++;
                          }
                          _holidaysFuture = _fetchHolidays(_selectedYear);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // --- CALENDÁRIO SEMANAL ---
  Widget _buildWeeklyCalendar() {
    final startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday % 7));
    final weekDays = <({String label, DateTime date})>[];
    final dayLabels = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    final monthNamesComplete = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

    // Calcular o número da semana (ISO 8601)
    final jan4 = DateTime(startOfWeek.year, 1, 4);
    final jan4Weekday = jan4.weekday % 7;
    final startOfYear = jan4.subtract(Duration(days: jan4Weekday));
    final weekNumber = ((startOfWeek.difference(startOfYear).inDays) ~/ 7) + 1;

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      weekDays.add((label: dayLabels[i], date: date));
    }
    
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        Map<String, String> holidayNames = {};
        Set<String> holidayDays = {};
        
        // Mostrar loading enquanto carrega
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Transform.scale(
            scale: 0.92,
            alignment: Alignment.topCenter,
            child: Card(
              elevation: 1,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: 16),
                    Text('Carregando feriados...', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData) {
          debugPrint('=== SEMANAL DEBUG ===');
          debugPrint('Total de feriados carregados: ${snapshot.data!.length}');
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              holidayDays.add(key);
              holidayNames[key] = holiday.name;
              debugPrint('Feriado: ${holiday.name} em $key');
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
          debugPrint('Feriados da semana ${startOfWeek.toIso8601String()}: ${holidayDays.length}');
        }
        
        return Transform.scale(
          scale: 0.92,
          alignment: Alignment.topCenter,
          child: Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // CABEÇALHO SEMANA/MÊS/ANO
                  Text(
                    'Semana: # $weekNumber - ${monthNamesComplete[startOfWeek.month - 1]} ${startOfWeek.year}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  SizedBox(height: 12),
                  // CONTEÚDO DA SEMANA
                  Row(
                    children: [
                      // SETA ESQUERDA
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 40,
                            icon: Icon(Icons.arrow_circle_left_rounded),
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                _selectedWeek = _selectedWeek.subtract(Duration(days: 7));
                                // Atualizar _selectedYear se mudar de ano
                                if (_selectedWeek.year != _selectedYear) {
                                  _selectedYear = _selectedWeek.year;
                                  _holidaysFuture = _fetchHolidays(_selectedYear);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      // SEMANA
                      Expanded(
                        child: Column(
                          children: weekDays.map((day) {
                            final now = DateTime.now();
                            final isToday = day.date.year == now.year && day.date.month == now.month && day.date.day == now.day;
                            final holidayKey = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
                            final isHoliday = holidayDays.contains(holidayKey);
                            final holidayName = isHoliday ? holidayNames[holidayKey] : null;
                            
                            Color bgColor = Colors.white;
                            Color textColor = Theme.of(context).colorScheme.onSurface;
                            
                            if (isToday) {
                              bgColor = Colors.blue;
                              textColor = Colors.white;
                            } else if (isHoliday) {
                              bgColor = Colors.green;
                              textColor = Colors.white;
                            } else if (day.label == 'DOM') { // Domingo
                              bgColor = Colors.red;
                              textColor = Colors.white;
                            } else if (day.label == 'SAB') { // Sábado
                              bgColor = Color(0xFFEF9A9A); // Vermelho mais claro
                              textColor = Colors.white;
                            }
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    day.label,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${day.date.day}',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                        ),
                                        if (isToday)
                                          Text('HOJE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
                                        if (isHoliday && holidayName != null)
                                          Text(
                                            holidayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // SETA DIREITA
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 40,
                            icon: Icon(Icons.arrow_circle_right_rounded),
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              setState(() {
                                _selectedWeek = _selectedWeek.add(Duration(days: 7));
                                // Atualizar _selectedYear se mudar de ano
                                if (_selectedWeek.year != _selectedYear) {
                                  _selectedYear = _selectedWeek.year;
                                  _holidaysFuture = _fetchHolidays(_selectedYear);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- CALENDÁRIO ANUAL ---
  Widget _buildAnnualCalendar() {
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        Map<String, String> holidayNames = {};
        Set<String> holidayDays = {};
        
        if (snapshot.hasData) {
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              holidayDays.add(key);
              holidayNames[key] = holiday.name;
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
        }
        
        return Transform.scale(
          scale: 0.95,
          alignment: Alignment.topCenter,
          child: Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // SETA ESQUERDA
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 40,
                        icon: Icon(Icons.arrow_circle_left_rounded),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          setState(() {
                            _selectedYear--;
                            _holidaysFuture = _fetchHolidays(_selectedYear);
                          });
                        },
                      ),
                    ),
                  ),
                  // GRID ANUAL
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              '$_selectedYear',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 0,
                          crossAxisSpacing: 0,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, monthIndex) {
                          final month = monthIndex + 1;
                          final monthNames = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
                          final now = DateTime.now();
                          final firstDayOfMonth = DateTime(_selectedYear, month, 1);
                          final firstDayOfWeek = firstDayOfMonth.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
                          final daysInMonth = DateTime(_selectedYear, month + 1, 0).day;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.black, width: 1.5),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(0.5),
                              child: Column(
                                children: [
                                  Text(
                                    monthNames[monthIndex],
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  // Header com dias da semana
                                  Row(
                                    children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                                        .map((day) => Expanded(
                                          child: Center(
                                            child: Text(
                                              day,
                                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ))
                                        .toList(),
                                  ),
                                  GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        childAspectRatio: 1.0,
                                        mainAxisSpacing: 0.0,
                                        crossAxisSpacing: 0.0,
                                      ),
                                      itemCount: firstDayOfWeek + daysInMonth,
                                      itemBuilder: (context, index) {
                                        if (index < firstDayOfWeek) {
                                          return SizedBox.shrink();
                                        }

                                        final day = index - firstDayOfWeek + 1;
                                        final dateObj = DateTime(_selectedYear, month, day);
                                        final dayOfWeek = dateObj.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
                                        final isToday = now.year == _selectedYear && now.month == month && now.day == day;
                                        final holidayKey = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                                        final isHoliday = holidayDays.contains(holidayKey);

                                        Color bgColor = Colors.white;
                                        Color textColor = Colors.black;

                                        if (isToday) {
                                          bgColor = Colors.blue;
                                          textColor = Colors.white;
                                        } else if (isHoliday) {
                                          // Feriados sempre verde com letras brancas, independente do dia da semana
                                          bgColor = Colors.green;
                                          textColor = Colors.white;
                                        } else if (dayOfWeek == 0) { // Domingo
                                          bgColor = Colors.red;
                                          textColor = Colors.white;
                                        } else if (dayOfWeek == 6) { // Sábado
                                          bgColor = Color(0xFFEF9A9A); // Vermelho mais claro
                                          textColor = Colors.white;
                                        }

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            border: Border.all(color: Colors.black, width: 0.3),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              day.toString(),
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                // FERIADOS DO MÊS
                                if (holidayDays.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (int day = 1; day <= daysInMonth; day++)
                                          ...[
                                            if (holidayNames.containsKey('$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}'))
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 3),
                                                child: Text(
                                                  '$day - ${holidayNames['$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}']!}',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                                                  textAlign: TextAlign.left,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                      ],
                                    ),
                                  ),
                                ],
                                ],
                              ),
                            ),
                          );
                        },
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // SETA DIREITA
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 40,
                        icon: Icon(Icons.arrow_circle_right_rounded),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          setState(() {
                            _selectedYear++;
                            _holidaysFuture = _fetchHolidays(_selectedYear);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final double fontSize = isMobile ? 18.0 : 16.0;
    final double cardPadding = isMobile ? 20.0 : 16.0;

    if (_isLoading) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: Theme.of(context).textTheme.titleMedium)])));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: isMobile ? 40 : 53,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.calculate),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Calcular Datas',
                  onPressed: () => _showDateCalculator(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Sobre',
                  onPressed: _showAbout,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'CalendarPRO v1.00',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // PRÓXIMO FERIADO (Grande)
                  FutureBuilder<({String name, int daysUntil})?>(
                    future: _getNextHoliday(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox.shrink();
                      }

                      if (snapshot.hasData && snapshot.data != null) {
                        final nextHoliday = snapshot.data!;
                        final daysWord = nextHoliday.daysUntil == 1 ? 'dia' : 'dias';

                        return Card(
                          elevation: 2,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.event_available, color: Theme.of(context).colorScheme.primary, size: 28),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Próximo Feriado',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        nextHoliday.name,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        nextHoliday.daysUntil.toString(),
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      Text(
                                        daysWord,
                                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SizedBox.shrink();
                    },
                  ),
                  SizedBox(height: 12),
                  // CIDADE E TIPO DE CALENDÁRIO (lado a lado)
                  Row(
                    children: [
                      // SELEÇÃO DE CIDADE
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<CityData>(
                            value: _selectedCity,
                            isExpanded: true,
                            underline: const SizedBox(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                            items: cities.where((city) => city.region == 'Vale do Paraíba').map((city) => DropdownMenuItem<CityData>(value: city, child: Text(city.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (newCity) {
                              if (newCity != null) {
                                setState(() {
                                  _selectedCity = newCity;
                                  _savePreferences();
                                  _reloadData();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // TIPO DE CALENDÁRIO
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: _calendarType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                            items: const [
                              DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                              DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                              DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                            ],
                            onChanged: (type) {
                              if (type != null) {
                                setState(() {
                                  _calendarType = type;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // BOTÃO PDF
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        color: Colors.grey[600],
                        iconSize: 24,
                        tooltip: 'Exportar PDF',
                        onPressed: () {
                          _showPdfExportPreview();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // CALENDÁRIO CONFORME TIPO SELECIONADO
                  if (_calendarType == 'mensal')
                    _buildCalendarGrid()
                  else if (_calendarType == 'semanal')
                    _buildWeeklyCalendar()
                  else if (_calendarType == 'anual')
                    _buildAnnualCalendar(),
                  SizedBox(height: isMobile ? 28 : 24),
                  FutureBuilder<List<Holiday>>(
                    future: _holidaysFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [CircularProgressIndicator(color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: TextStyle(color: Colors.grey[600], fontSize: fontSize))])));
                      } else if (snapshot.hasError) {
                        return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [Icon(Icons.error_outline, size: 48, color: Colors.red[300]), const SizedBox(height: 16), Text('Erro ao carregar feriados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: fontSize), textAlign: TextAlign.center), const SizedBox(height: 8), Text('${snapshot.error}', style: TextStyle(color: Colors.grey[600], fontSize: fontSize - 4), textAlign: TextAlign.center)])));
                      } else if (snapshot.hasData) {
                        final holidays = snapshot.data!;
                        if (holidays.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [Icon(Icons.event_busy, size: 48, color: Colors.grey[400]), const SizedBox(height: 16), Text('Nenhum feriado encontrado', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: fontSize))])));

                        // Filtra apenas feriados do ano selecionado
                        final holidaysCurrentYear = holidays.where((h) {
                          try {
                            final year = DateTime.parse(h.date).year;
                            return year == _selectedYear;
                          } catch (e) {
                            return false;
                          }
                        }).toList();

                        // Deduplica feriados por data
                        final Map<String, Holiday> uniqueHolidaysMap = {};
                        for (var holiday in holidaysCurrentYear) {
                          if (!uniqueHolidaysMap.containsKey(holiday.date)) {
                            uniqueHolidaysMap[holiday.date] = holiday;
                          }
                        }
                        final uniqueHolidays = uniqueHolidaysMap.values.toList();

                        final stats = _calculateStats(holidaysCurrentYear);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainStatsSummary(stats, fontSize), // ESTATISTICAS NA TELA PRINCIPAL (LIMPO E COLORIDO)
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(Icons.event_note, color: Theme.of(context).colorScheme.primary, size: isMobile ? 28 : 24), const SizedBox(width: 8), Expanded(child: Text('Lista de Feriados de $_selectedYear', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 4)))])),
                              SizedBox(height: isMobile ? 16 : 12),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: uniqueHolidays.length,
                                itemBuilder: (context, index) {
                                  final holiday = uniqueHolidays[index];
                                  final formattedDate = _formatDate(holiday.date);
                                  bool isWeekend = false;
                                  try { isWeekend = (DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.saturday || DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.sunday); } catch (e) {
                                    // Ignorar erro na análise de fim de semana
                                  }
                                  return Card(
                                    elevation: 1,
                                    color: isWeekend ? Colors.green : null,
                                    margin: EdgeInsets.only(bottom: isMobile ? 12 : 8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () { HapticFeedback.lightImpact(); },
                                      child: Padding(
                                        padding: EdgeInsets.all(isMobile ? 18 : 16),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Column(children: holiday.types.map((type) {
                                              Color typeColor = Colors.grey;
                                              if (type.contains('Bancário')) typeColor = Colors.green;
                                              if (type.contains('Nacional')) typeColor = Colors.blue;
                                              if (type.contains('Estadual')) typeColor = Colors.purple;
                                              if (type.contains('Municipal')) typeColor = Colors.orange;
                                              return Container(margin: const EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(isMobile ? 14 : 12), decoration: BoxDecoration(color: isWeekend ? Colors.white.withValues(alpha: 0.2) : typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event, color: isWeekend ? Colors.white : typeColor, size: isMobile ? 28 : 24));
                                            }).toList()),
                                            SizedBox(width: isMobile ? 18 : 16),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(holiday.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? fontSize + 2 : fontSize, color: isWeekend ? Colors.white : null)), SizedBox(height: isMobile ? 6 : 4), Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isWeekend ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]), fontWeight: isWeekend ? FontWeight.w600 : FontWeight.normal, fontSize: isMobile ? fontSize : fontSize - 2)), SizedBox(height: isMobile ? 6 : 4), Wrap(spacing: 6, runSpacing: 6, children: holiday.types.map((type) { Color typeColor = Colors.grey; if (type.contains('Bancário')) typeColor = Colors.green; if (type.contains('Nacional')) typeColor = Colors.blue; if (type.contains('Estadual')) typeColor = Colors.purple; if (type.contains('Municipal')) typeColor = Colors.orange; return Container(padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 8, vertical: isMobile ? 6 : 4), decoration: BoxDecoration(color: isWeekend ? Colors.white.withValues(alpha: 0.2) : typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(type, style: TextStyle(fontSize: isMobile ? 13 : 11, color: isWeekend ? Colors.white : typeColor, fontWeight: FontWeight.w600))); }).toList()), if (holiday.specialNote != null) ...[SizedBox(height: isMobile ? 8 : 6), Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: isWeekend ? Colors.white.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: isWeekend ? Colors.white.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3), width: 1)), child: Row(children: [Icon(Icons.access_time, size: isMobile ? 18 : 16, color: isWeekend ? Colors.white : Colors.amber[800]), SizedBox(width: isMobile ? 8 : 6), Expanded(child: Text(holiday.specialNote!, style: TextStyle(fontSize: isMobile ? 13 : 11, color: isWeekend ? Colors.white : Colors.amber[900], fontWeight: FontWeight.w500))) ]))]])),
                                            if (isWeekend) Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(Icons.weekend, color: Colors.white, size: isMobile ? 24 : 20)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  SizedBox(height: isMobile ? 28 : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === FIM DO ARQUIVO ===