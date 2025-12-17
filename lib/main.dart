import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';


// Versão do App
const String APP_VERSION = '2.8.0';
const String APP_BUILD = '22';
const String API_SOURCE = 'BrasilAPI - https://brasilapi.com.br/api/feriados/v1/';

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
  late CityData _selectedCity;
  String? _selectedRegion; 
  late Future<List<Holiday>> _holidaysFuture;
  late AnimationController _animationController;
  bool _isLoading = true;
  bool _isDarkMode = false;
  
  final List<int> availableYears = List.generate(11, (index) => DateTime.now().year - 5 + index);
  
  final List<String> regions = [
    'SP e Grande SP',
    'Vale do Paraíba',
    'Litoral Norte',
    'Litoral Sul',
    'Sul de Minas',
  ];

  late final List<CityData> cities;
  
  @override
  void initState() {
    super.initState();
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
    _selectedRegion = _selectedCity.region; 
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
          _selectedRegion = _selectedCity.region;
        }
      }
      final savedYear = prefs.getInt('selectedYear');
      if (savedYear != null && availableYears.contains(savedYear)) _selectedYear = savedYear;
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
      await prefs.setInt('selectedYear', _selectedYear);
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  Future<List<Holiday>> _fetchHolidays(int year) async {
    final uriNacional = Uri.parse('https://brasilapi.com.br/api/feriados/v1/$year');
    Map<String, Holiday> holidaysMap = {};
    
    try {
      final response = await http.get(uriNacional);
      if (response.statusCode == 200) {
        List jsonList = json.decode(response.body);
        for (var json in jsonList) {
          final holiday = Holiday.fromJson(json);
          holidaysMap[holiday.date] = holiday;
        }
        final lastDay = DateTime(year, 12, 31);
        String specialNote = '';
        if (lastDay.weekday == DateTime.saturday) {
          specialNote = 'Bancos encerram às 11h na sexta-feira anterior (30/12)';
        } else if (lastDay.weekday == DateTime.sunday) {
          specialNote = 'Bancos encerram às 11h na sexta-feira anterior (29/12)';
        } else {
          specialNote = 'Bancos encerram às 11h';
        }
        final bancarioHoliday = Holiday(date: '$year-12-31', name: 'Último Dia Útil do Ano', types: ['Bancário'], specialNote: specialNote);
        if (holidaysMap.containsKey(bancarioHoliday.date)) {
          holidaysMap[bancarioHoliday.date] = holidaysMap[bancarioHoliday.date]!.mergeWith(bancarioHoliday);
        } else {
          holidaysMap[bancarioHoliday.date] = bancarioHoliday;
        }
        for (var holiday in _selectedCity.municipalHolidays) {
          final date = '$year${holiday['date']}';
          final municipalHoliday = Holiday(date: date, name: holiday['name']!, types: ['Municipal (${_selectedCity.name})']);
          if (holidaysMap.containsKey(date)) {
            holidaysMap[date] = holidaysMap[date]!.mergeWith(municipalHoliday);
          } else {
            holidaysMap[date] = municipalHoliday;
          }
        }
        final allHolidays = holidaysMap.values.toList();
        allHolidays.sort((a, b) => a.date.compareTo(b.date));
        return allHolidays;
      } else {
        throw Exception('Falha ao carregar feriados nacionais.');
      }
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
                  'Versão $APP_VERSION (Build $APP_BUILD)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
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
                
                // BOTÃO DE MODO ESCURO (MOVIDO PARA CÁ)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
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
                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
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
                        API_SOURCE,
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

  HolidayStats _calculateStats(List<Holiday> holidays) {
    final stats = HolidayStats();
    for (var holiday in holidays) {
      for (var type in holiday.types) {
        if (type.contains('Bancário')) stats.bancarios++;
        if (type.contains('Nacional')) stats.nacionais++;
        if (type.contains('Estadual')) stats.estaduais++;
        if (type.contains('Municipal')) stats.municipais++;
      }
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
      } catch (e) {}
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
            Text('RESUMO DO ANO', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 2, color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildStatBadge('Dias Úteis', stats.diasUteis, Colors.indigo, fontSize)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatBadge('Finais de Semana', stats.finaisSemana, Colors.red, fontSize)),
              ],
            ),
            const Divider(height: 24),
             Text('Por Tipo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Uso de cores dinâmicas para fundo (claro em Light, transparente em Dark) e texto (preto em Light, branco em Dark)
            _buildStatRow(context, 'Nacionais', stats.nacionais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50]),
            _buildStatRow(context, 'Municipais', stats.municipais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange[50]),
            _buildStatRow(context, 'Bancários', stats.bancarios, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.green.withOpacity(0.2) : Colors.green[50]),
            _buildStatRow(context, 'Estaduais', stats.estaduais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple[50]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatBadge(String label, int value, Color color, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Text(value.toString(), style: TextStyle(fontSize: fontSize + 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: fontSize - 2, color: color.withOpacity(0.8), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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

  // --- POPUP: RESUMO COMPLETO ---
  void _showSummary() async {
    final holidays = await _holidaysFuture;
    final stats = _calculateStats(holidays);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 500, maxHeight: size.height * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28)),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('RESUMO', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Análise de Feriados', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                      ])),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(context, icon: Icons.calendar_today, label: 'Ano', value: _selectedYear.toString(), color: Colors.blue),
                        const SizedBox(height: 8),
                        _buildSummaryCard(context, icon: Icons.location_city, label: 'Cidade', value: _selectedCity.name, color: Colors.orange),
                        
                        const Divider(height: 32),

                        Text('Por Tipo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        // Uso de cores dinâmicas no popup
                        _buildStatRow(context, 'Feriados Bancários', stats.bancarios, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.green.withOpacity(0.2) : Colors.green[50]),
                        _buildStatRow(context, 'Feriados Nacionais', stats.nacionais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50]),
                        _buildStatRow(context, 'Feriados Estaduais', stats.estaduais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple[50]),
                        _buildStatRow(context, 'Feriados Municipais', stats.municipais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange[50]),
                        
                        const Divider(height: 32),
                        
                        Text('Por Mês', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...(() {
                           final entries = stats.monthlyStats.entries.toList();
                           entries.sort((a, b) => a.key.compareTo(b.key));
                           return entries.asMap().entries.map((mapEntry) {
                             int idx = mapEntry.key;
                             var entry = mapEntry.value;
                             // Zebra Dinâmica
                             Color bg = idx.isEven 
                                 ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!) 
                                 : Colors.transparent;
                             return Padding(
                               padding: const EdgeInsets.symmetric(vertical: 2),
                               child: _buildStatRow(context, entry.value.monthName, entry.value.totalDays, isDark ? Colors.white : Colors.black87, backgroundColor: bg),
                             );
                           });
                        })(),

                        const Divider(height: 32),
                        
                        Text('Por Dia da Semana', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...[
                          {'label': 'Segundas-Feiras', 'val': stats.segundas},
                          {'label': 'Terças-Feiras', 'val': stats.tercas},
                          {'label': 'Quartas-Feiras', 'val': stats.quartas},
                          {'label': 'Quintas-Feiras', 'val': stats.quintas},
                          {'label': 'Sextas-Feiras', 'val': stats.sextas},
                        ].asMap().entries.map((entry) {
                           int idx = entry.key;
                           var data = entry.value;
                           // Zebra Dinâmica
                           Color bg = idx.isEven 
                               ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!) 
                               : Colors.transparent;
                           return _buildStatRow(context, data['label'] as String, data['val'] as int, isDark ? Colors.white : Colors.black87, backgroundColor: bg);
                        }).toList(),
                        
                        const Divider(height: 24),
                        
                        _buildStatRow(context, 'Total de Feriados Dias Úteis', stats.diasUteis, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.indigo.withOpacity(0.2) : Colors.indigo[50]),
                        _buildStatRow(context, 'Finais de Semana', stats.finaisSemana, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.red.withOpacity(0.2) : Colors.red[50]),
                        
                        const Divider(height: 32),
                        
                        Text('Histórico (Dias Úteis)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        FutureBuilder<List<YearlyData>>(
                          future: _fetchYearlyData(_selectedYear),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) return _buildYearlyChart(snapshot.data!, _selectedYear);
                            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _exportToPdf(holidays, stats);
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('EXPORTAR PDF'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Container(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR')))),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]))),
          Flexible(child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final double fontSize = isMobile ? 18.0 : 16.0;
    final double buttonPadding = isMobile ? 20.0 : 16.0;
    final double cardPadding = isMobile ? 20.0 : 16.0;

    if (_isLoading) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: Theme.of(context).textTheme.titleMedium)])));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: isMobile ? 120 : 160,
            pinned: true,
            actions: [
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
            flexibleSpace: FlexibleSpaceBar(title: Text('Feriados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 22 : 20)), background: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)])))),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int>(
                            decoration: InputDecoration(labelText: 'Ano', labelStyle: TextStyle(fontSize: fontSize), prefixIcon: Icon(Icons.calendar_month, size: isMobile ? 28 : 24), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).colorScheme.surface),
                            value: _selectedYear,
                            style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                            items: availableYears.map((year) => DropdownMenuItem<int>(value: year, child: Text(year.toString(), style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.w600)))).toList(),
                            onChanged: (newYear) { if (newYear != null) { setState(() { _selectedYear = newYear; }); _reloadData(); } },
                          ),
                          SizedBox(height: isMobile ? 20 : 16),
                          
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Região', labelStyle: TextStyle(fontSize: fontSize), prefixIcon: Icon(Icons.map, size: isMobile ? 28 : 24), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).colorScheme.surface),
                            value: _selectedRegion,
                            isExpanded: true,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                            items: regions.map((region) => DropdownMenuItem<String>(value: region, child: Text(region, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500)))).toList(),
                            onChanged: (newRegion) {
                              if (newRegion != null) {
                                setState(() {
                                  _selectedRegion = newRegion;
                                  final citiesInRegion = cities.where((c) => c.region == newRegion).toList();
                                  if (citiesInRegion.isNotEmpty) {
                                    _selectedCity = citiesInRegion.first;
                                  }
                                  _savePreferences();
                                  _reloadData();
                                });
                              }
                            },
                          ),
                          SizedBox(height: isMobile ? 20 : 16),

                          DropdownButtonFormField<CityData>(
                            decoration: InputDecoration(labelText: 'Cidade', labelStyle: TextStyle(fontSize: fontSize), prefixIcon: Icon(Icons.location_on, size: isMobile ? 28 : 24), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Theme.of(context).colorScheme.surface),
                            value: _selectedCity,
                            isExpanded: true,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                            items: cities.where((city) => city.region == _selectedRegion).map((city) => DropdownMenuItem<CityData>(value: city, child: Text(city.name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (newCity) { if (newCity != null) { setState(() { _selectedCity = newCity; }); _savePreferences(); _reloadData(); } },
                          ),
                          SizedBox(height: isMobile ? 24 : 20),
                          ElevatedButton.icon(
                            onPressed: _showSummary,
                            icon: Icon(Icons.analytics_rounded, size: isMobile ? 26 : 22),
                            label: Text('RESUMO COMPLETO', style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary, padding: EdgeInsets.symmetric(vertical: buttonPadding)),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                        final stats = _calculateStats(holidays);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainStatsSummary(stats, fontSize), // ESTATISTICAS NA TELA PRINCIPAL (LIMPO E COLORIDO)
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(Icons.event_note, color: Theme.of(context).colorScheme.primary, size: isMobile ? 28 : 24), const SizedBox(width: 8), Expanded(child: Text('Lista de Feriados de $_selectedYear', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 4)))])),
                              SizedBox(height: isMobile ? 16 : 12),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: holidays.length,
                                itemBuilder: (context, index) {
                                  final holiday = holidays[index];
                                  final formattedDate = _formatDate(holiday.date);
                                  bool isWeekend = false;
                                  try { isWeekend = (DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.saturday || DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.sunday); } catch (e) {}
                                  return Card(
                                    elevation: 1,
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
                                              return Container(margin: const EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(isMobile ? 14 : 12), decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event, color: typeColor, size: isMobile ? 28 : 24));
                                            }).toList()),
                                            SizedBox(width: isMobile ? 18 : 16),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(holiday.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? fontSize + 2 : fontSize)), SizedBox(height: isMobile ? 6 : 4), Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isWeekend ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]), fontWeight: isWeekend ? FontWeight.w600 : FontWeight.normal, fontSize: isMobile ? fontSize : fontSize - 2)), SizedBox(height: isMobile ? 6 : 4), Wrap(spacing: 6, runSpacing: 6, children: holiday.types.map((type) { Color typeColor = Colors.grey; if (type.contains('Bancário')) typeColor = Colors.green; if (type.contains('Nacional')) typeColor = Colors.blue; if (type.contains('Estadual')) typeColor = Colors.purple; if (type.contains('Municipal')) typeColor = Colors.orange; return Container(padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 8, vertical: isMobile ? 6 : 4), decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(type, style: TextStyle(fontSize: isMobile ? 13 : 11, color: typeColor, fontWeight: FontWeight.w600))); }).toList()), if (holiday.specialNote != null) ...[SizedBox(height: isMobile ? 8 : 6), Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1)), child: Row(children: [Icon(Icons.access_time, size: isMobile ? 18 : 16, color: Colors.amber[800]), SizedBox(width: isMobile ? 8 : 6), Expanded(child: Text(holiday.specialNote!, style: TextStyle(fontSize: isMobile ? 13 : 11, color: Colors.amber[900], fontWeight: FontWeight.w500))) ]))]])),
                                            if (isWeekend) Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.weekend, color: Colors.red, size: isMobile ? 24 : 20)),
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

  Future<List<YearlyData>> _fetchYearlyData(int centerYear) async {
    List<YearlyData> yearlyData = [];
    for (int offset = -5; offset <= 5; offset++) {
      int year = centerYear + offset;
      try {
        final holidays = await _fetchHolidays(year);
        int weekdayCount = holidays.where((h) {
          try {
            final date = DateFormat('yyyy-MM-dd').parse(h.date);
            return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
          } catch (e) {
            return false;
          }
        }).length;
        yearlyData.add(YearlyData(year, weekdayCount));
      } catch (e) {
        yearlyData.add(YearlyData(year, 0));
      }
    }
    return yearlyData;
  }

  // --- CHART AGORA É LINE CHART ---
  Widget _buildYearlyChart(List<YearlyData> yearlyData, int selectedYear) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: LineChart( 
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    '${flSpot.y.toInt()} dias',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < yearlyData.length) {
                    final year = yearlyData[value.toInt()].year;
                    final isSelected = year == selectedYear;
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(year.toString(), style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.red : Colors.grey[700])),
                    );
                  }
                  return const Text('');
                },
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                reservedSize: 28,
                interval: 2,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: yearlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weekdayHolidays.toDouble())).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPdf(List<Holiday> holidays, HolidayStats stats) async {
    try {
      final pdf = await _generateHolidaysPdf(holidays, stats);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF gerado com sucesso!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
    }
  }

  Future<pw.Document> _generateHolidaysPdf(List<Holiday> holidays, HolidayStats stats) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> pdfBody = [
            pw.Header(level: 0, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Feriados Vale do Paraíba/Sul de Minas', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Ano: $_selectedYear | Cidade: ${_selectedCity.name} (${_selectedCity.region})', style: const pw.TextStyle(fontSize: 14)),
              pw.Divider(thickness: 2),
            ])),
            pw.SizedBox(height: 20),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('RESUMO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('Por Tipo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _buildPdfStatRow('Feriados Bancários', stats.bancarios),
                _buildPdfStatRow('Feriados Nacionais', stats.nacionais),
                _buildPdfStatRow('Feriados Estaduais', stats.estaduais),
                _buildPdfStatRow('Feriados Municipais', stats.municipais),
                pw.SizedBox(height: 12), pw.Divider(), pw.SizedBox(height: 12),
                
                // CORREÇÃO: Removida a redundância no texto do mês
                pw.Text('Por Mês', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ...(() {
                  final sortedMonthlyStats = stats.monthlyStats.entries.toList();
                  sortedMonthlyStats.sort((a, b) => a.key.compareTo(b.key));
                  return sortedMonthlyStats.map((entry) {
                    final monthStat = entry.value;
                    // Removido o texto redundante "X dias", apenas o nome do mês
                    return _buildPdfStatRow(monthStat.monthName, monthStat.totalDays);
                  }).toList();
                })(),
                
                pw.SizedBox(height: 12), pw.Divider(), pw.SizedBox(height: 12),
                pw.Text('Por Dia da Semana', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                _buildPdfStatRow('Segundas-Feiras', stats.segundas),
                _buildPdfStatRow('Terças-Feiras', stats.tercas),
                _buildPdfStatRow('Quartas-Feiras', stats.quartas),
                _buildPdfStatRow('Quintas-Feiras', stats.quintas),
                _buildPdfStatRow('Sextas-Feiras', stats.sextas),
                _buildPdfStatRow('Finais de Semana', stats.finaisSemana),
                pw.SizedBox(height: 8), pw.Divider(), pw.SizedBox(height: 8),
                _buildPdfStatRow('Total de Feriados Dias Úteis', stats.diasUteis, bold: true),
              ]),
            ),
            
            // CORREÇÃO CRÍTICA DO PDF: QUEBRA DE PÁGINA **ANTES** DO TÍTULO E TABELA
            pw.NewPage(), 
            pw.Text('Lista de Feriados', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
          ];

          pdfBody.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: [
                  _buildPdfTableCell('Data', isHeader: true),
                  _buildPdfTableCell('Feriado', isHeader: true),
                  _buildPdfTableCell('Tipo', isHeader: true),
                ]),
                ...holidays.asMap().entries.map((entry) {
                  final index = entry.key;
                  final holiday = entry.value;
                  final isOdd = index.isOdd;
                  final formattedDate = _formatDate(holiday.date);
                  final types = holiday.types.join(', ');
                  return pw.TableRow(decoration: pw.BoxDecoration(color: isOdd ? PdfColors.grey100 : PdfColors.white), children: [
                    _buildPdfTableCell(formattedDate),
                    _buildPdfTableCell(holiday.name),
                    _buildPdfTableCell(types),
                  ]);
                }).toList(),
              ],
            ),
          );
          return pdfBody;
        },
      ),
    );
    return pdf;
  }

  pw.Widget _buildPdfStatRow(String label, int value, {bool bold = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)), pw.Text(value.toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]));
  }

  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text, style: pw.TextStyle(fontSize: isHeader ? 11 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)));
  }
}