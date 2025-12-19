# Instruções para Agentes de IA - Feriados Brasil App

## Visão Geral do Projeto

**Feriados Brasil** é um aplicativo Flutter profissional (v2.8.0) para consulta de feriados brasileiros em 79 cidades. Consiste principalmente em um único arquivo monolítico (`lib/main.dart`) contendo toda a lógica da aplicação.

### Arquitetura Principal

- **Monolítico**: Toda a UI, lógica de negócio e modelos estão em `lib/main.dart` (~1314 linhas)
- **Modelos de Dados**: `Holiday`, `CityData`, `HolidayStats`, `MonthStats` definidos inline
- **Arquivos Modulares** não utilizados:
  - `lib/models/` (holiday.dart, city_data.dart) - estrutura preparada mas não usada
  - `lib/screens/` - vazio
  - `lib/data/` - vazio
- **Dados Municipais**: Hardcoded em `_initializeCities()` com 79 cidades distribuídas em 5 regiões

### Fluxo de Dados Principal

1. **Inicialização** (`main()`): Configura locale pt_BR, carrega preferências via SharedPreferences
2. **Busca de Feriados**: `_fetchHolidays(year)` → HTTP GET da BrasilAPI → Merge com feriados municipais
3. **Renderização**: Exibe por região/cidade, filtrável por ano (±5 anos)
4. **Exportação**: Gera PDF com tabela zebrada via `pdf` + `printing` packages

## Conhecimento Crítico para Desenvolvimento

### Dependências Externas

```yaml
http: ^1.1.0              # Fetch feriados nacionais de BrasilAPI
intl: ^0.20.2             # Localização pt_BR, formatação de datas
shared_preferences: ^2.2.2 # Persistência: cidade, ano, tema
pdf: ^3.11.0              # Geração de PDF
printing: ^5.12.0         # UI de impressão/PDF
fl_chart: ^0.66.0         # Gráficos estatísticos
```

**API Externa**: BrasilAPI (`https://brasilapi.com.br/api/feriados/v1/{year}`) retorna feriados nacionais em JSON.

### Padrões de Código Específicos

#### 1. **Combinação de Feriados Nacionais + Municipais**
```dart
// Holiday.mergeWith() combina tipos de diferentes origens
final combinedTypes = {...types, ...other.types}.toList();
```
A lógica de merge é crítica: mesmo feriado pode ter múltiplos tipos (Nacional + Municipal).

#### 2. **Persistência de Preferências**
```dart
// SharedPreferences carrega: selectedCity, selectedYear, isDarkMode
final prefs = await SharedPreferences.getInstance();
prefs.getString('selectedCity')   // Cidade selecionada
prefs.getInt('selectedYear')      // Ano para exibição
prefs.getBool('isDarkMode')       // Tema persistido
```

#### 3. **Tema Dinâmico com Material3**
- Tema claro: `ColorScheme.fromSeed(seedColor: 0xFF1976D2, brightness: Brightness.light)`
- Tema escuro: Cores customizadas (`#1E1E1E` cards, `#121212` fundo) para legibilidade
- Alternância via `ThemeMode` na raiz do app

#### 4. **Cidades Organizadas por Região**
```dart
// 5 regiões: 'SP e Grande SP', 'Vale do Paraíba', 'Litoral Norte', 
//           'Litoral Sul', 'Sul de Minas'
// Cada cidade tem lista de feriados municipais: [{'date': '-MM-DD', 'name': '...'}]
```
Datas municipais usam formato `-MM-DD` (sem ano) para merge com dados anuais.

#### 5. **Estatísticas de Feriados**
A classe `HolidayStats` rastreia: bancários, nacionais, estaduais, municipais, por dia da semana, dias úteis, fins de semana. Exibida em `_showSummary()`.

### Comandos de Desenvolvimento

```bash
# Instalar dependências
flutter pub get

# Executar em dispositivo/emulador
flutter run

# Modo release (Windows)
flutter build windows

# Modo debug
flutter run -v

# Testar widget (single test file exists)
flutter test
```

**Arquivo de configuração**: `pubspec.yaml` contém versão `2.4.0+6` (build number crítico para instalador Windows).

### Estrutura de Pastas - Estado Atual

```
lib/
├── main.dart            ⭐ 90% da lógica aqui
├── models/              📦 Não usado (legacy structure)
│   ├── holiday.dart
│   └── city_data.dart
├── utils/
│   └── constants.dart   (versionamento básico)
└── data/                📦 Vazio

build/
├── web/                 (assets Flutter web compilados)
└── windows/             (builds Windows)
```

### Padrões Não-Óbvios

1. **Encoding UTF-8**: Scripts PowerShell (fix-encoding.ps1, fix-utf8.ps1) indicam problemas históricos com codificação de acentos
2. **Backups em lib/**: main.dart.bkp, main.dart_ok2 são versões anteriores - ignore
3. **Instalador Windows**: feriados_installer.iss (Inno Setup) para distribuição desktop
4. **Locale Hardcoded**: Sempre `pt_BR`, sem suporte a outros idiomas

## Fluxo de Trabalho Recomendado

### Para Adicionar Nova Funcionalidade

1. **Se é UI/Screens**: Crie arquivo em `lib/screens/` (hoje vazio) e importe em main.dart
2. **Se é modelo/dados**: Considere mover para `lib/models/` - estrutura existe mas não é usada
3. **Se é utilidade**: Estenda `lib/utils/constants.dart`
4. **Se é lógica de feriados**: Modifique `_fetchHolidays()` ou `Holiday` class

### Para Refatorar

**Prioridade Alta**: O monolito é difícil de manter. Sugestões:
- Extrair `_HolidayScreenState` para arquivo separado
- Mover `HolidayStats`, `MonthStats` para `lib/models/`
- Criar `services/holiday_service.dart` para lógica de fetch/merge

### Para Debugar

1. **Print de feriados**: Use `debugPrint()` já no código
2. **SharedPreferences**: Verificar com plugin DevTools
3. **Tema**: Alternar `_isDarkMode` e aguardar rebuild
4. **PDF**: Usar `printing.onPrintError` para capturar erros

## Convenções de Código

- **Variáveis privadas**: Prefix `_` (ex: `_selectedCity`, `_holidaysFuture`)
- **Constantes globais**: UPPERCASE (ex: `APP_VERSION`, `API_SOURCE`)
- **Comentários**: Seções delimitadas com `=== DESCRIÇÃO ===`
- **Async**: Sempre use `Future<T>`, nunca callbacks
- **Null-safety**: Utiliza `?` para opcionais, `!` para force unwrap (risco)

## Próximos Passos Recomendados

1. Refatorar monolito em múltiplos arquivos
2. Adicionar testes unitários (test/ existe vazio)
3. Separar camada de dados (HTTP) em serviço reutilizável
4. Considerar Provider/GetX para state management
5. Validar URLs e tratamento de erros HTTP
