import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateCalculatorDialog extends StatefulWidget {
  final DateTime referenceDate;
  final List<dynamic> holidays;
  final dynamic selectedCity;

  const DateCalculatorDialog({
    super.key,
    required this.referenceDate,
    required this.holidays,
    required this.selectedCity,
  });

  @override
  State<DateCalculatorDialog> createState() => _DateCalculatorDialogState();
}

class _DateCalculatorDialogState extends State<DateCalculatorDialog> {
  late DateTime _referenceDate;
  late DateTime _calculatedDate;
  late int _daysCount;
  late String _dayType; // 'uteis' ou 'totais'
  late String _direction; // 'frente' ou 'tras'
  late TextEditingController _daysController;
  late String _selectedCityName;

  @override
  void initState() {
    super.initState();
    _referenceDate = widget.referenceDate;
    _calculatedDate = widget.referenceDate;
    _daysCount = 0;
    _dayType = 'uteis';
    _direction = 'frente';
    _daysController = TextEditingController(text: '0');
    // Extrair o nome da cidade do objeto CityData
    _selectedCityName = widget.selectedCity?.name ?? 'Não definida';
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _calculateDate() {
    DateTime result = _referenceDate;
    int daysToAdd = _daysCount;
    if (_direction == 'tras') {
      daysToAdd = -daysToAdd;
    }

    if (_dayType == 'uteis') {
      // Calcular apenas dias úteis (ignorando feriados e fins de semana)
      final holidays = _getHolidayDays();
      int count = 0;
      int dayIncrement = daysToAdd > 0 ? 1 : -1;
      while (count.abs() < daysToAdd.abs()) {
        result = result.add(Duration(days: dayIncrement));
        // Verificar se é dia útil (não é sábado=6 nem domingo=7 e não é feriado)
        final dayKey = '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
        if (result.weekday != 6 && result.weekday != 7 && !holidays.contains(dayKey)) {
          count += dayIncrement;
        }
      }
    } else {
      // Calcular dias totais (corridos)
      result = result.add(Duration(days: daysToAdd));
    }

    setState(() {
      _calculatedDate = result;
    });
  }

  Set<String> _getHolidayDays() {
    Set<String> holidays = {};
    for (var holiday in widget.holidays) {
      try {
        final holidayDate = DateTime.parse(holiday.date);
        final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
        holidays.add(key);
      } catch (e) {
        // Ignorar feriados inválidos
      }
    }
    return holidays;
  }

  String _getDayOfWeekName(DateTime date) {
    final dayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return dayNames[date.weekday % 7];
  }

  String _getDayTypeLabel() {
    return _dayType == 'uteis' ? 'Úteis' : 'Corridos';
  }

  Map<String, String> _generatePdfData() {
    final refDateFormatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(_referenceDate);
    final calcDateFormatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(_calculatedDate);
    final refDayOfWeek = _getDayOfWeekName(_referenceDate);
    final calcDayOfWeek = _getDayOfWeekName(_calculatedDate);

    return {
      'cidade': _selectedCityName,
      'dataReferencia': '$refDateFormatted ($refDayOfWeek)',
      'dias': '$_daysCount ${_getDayTypeLabel()}',
      'dataCalculada': '$calcDateFormatted ($calcDayOfWeek)',
    };
  }

  void _showPdfPreview(BuildContext context, Map<String, String> data) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? 500 : 1000,
            maxHeight: isMobile ? 600 : 700,
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Preview - Exportação em PDF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Dois calendários lado a lado
                if (!isMobile)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 350),
                          child: _buildCalendarPanel(_referenceDate, isReference: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 350),
                          child: _buildCalendarPanel(_calculatedDate, isReference: false),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 350),
                        child: _buildCalendarPanel(_referenceDate, isReference: true),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 350),
                        child: _buildCalendarPanel(_calculatedDate, isReference: false),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Tabela zebrada com resumo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPdfTableRow('Cidade:', data['cidade']!, true),
                      _buildPdfTableRow('Data Referência:', data['dataReferencia']!, false),
                      _buildPdfTableRow('Dias:', data['dias']!, true),
                      _buildPdfTableRow('Data Calculada:', data['dataCalculada']!, false),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfTableRow(String label, String value, bool isStriped) {
    return Container(
      color: isStriped ? Colors.white : Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPanel(DateTime date, {bool isReference = false}) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
    final holidays = _getHolidayDays();

    final monthName = DateFormat('MMMM', 'pt_BR').format(date);
    final year = date.year;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título Data Referência ou Data Calculada (grande, bold, centralizado)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      isReference ? 'Data Referência' : 'Data Calculada',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Botão Reset (apenas para referência)
                if (isReference)
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.refresh),
                    color: Colors.grey[600],
                    tooltip: 'Voltar para hoje',
                    onPressed: () {
                      setState(() {
                        final today = DateTime.now();
                        _referenceDate = DateTime(today.year, today.month, today.day);
                        _calculateDate();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Seletor Mês e Ano (MÊS primeiro, depois ANO)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Setas do Mês
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.arrow_left),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (isReference) {
                            if (_referenceDate.month == 1) {
                              _referenceDate = DateTime(_referenceDate.year - 1, 12, 1);
                            } else {
                              _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, 1);
                            }
                            _calculateDate();
                          } else {
                            if (_calculatedDate.month == 1) {
                              _calculatedDate = DateTime(_calculatedDate.year - 1, 12, 1);
                            } else {
                              _calculatedDate = DateTime(_calculatedDate.year, _calculatedDate.month - 1, 1);
                            }
                          }
                        });
                      },
                    ),
                    Text(
                      monthName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.arrow_right),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (isReference) {
                            if (_referenceDate.month == 12) {
                              _referenceDate = DateTime(_referenceDate.year + 1, 1, 1);
                            } else {
                              _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 1);
                            }
                            _calculateDate();
                          } else {
                            if (_calculatedDate.month == 12) {
                              _calculatedDate = DateTime(_calculatedDate.year + 1, 1, 1);
                            } else {
                              _calculatedDate = DateTime(_calculatedDate.year, _calculatedDate.month + 1, 1);
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Setas do Ano
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.arrow_left),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (isReference) {
                            _referenceDate = DateTime(_referenceDate.year - 1, _referenceDate.month, 1);
                            _calculateDate();
                          } else {
                            _calculatedDate = DateTime(_calculatedDate.year - 1, _calculatedDate.month, 1);
                          }
                        });
                      },
                    ),
                    Text(
                      year.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: const Icon(Icons.arrow_right),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        setState(() {
                          if (isReference) {
                            _referenceDate = DateTime(_referenceDate.year + 1, _referenceDate.month, 1);
                            _calculateDate();
                          } else {
                            _calculatedDate = DateTime(_calculatedDate.year + 1, _calculatedDate.month, 1);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Header dias da semana
            Row(
              children: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Grid de dias
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: firstDayOfWeek + lastDay.day,
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek) {
                  return const SizedBox.shrink();
                }
                final day = index - firstDayOfWeek + 1;
                final currentDate = DateTime(date.year, date.month, day);

                final isReferenceSelected = isReference &&
                    currentDate.year == _referenceDate.year &&
                    currentDate.month == _referenceDate.month &&
                    currentDate.day == _referenceDate.day;

                final isCalculated = !isReference &&
                    currentDate.year == _calculatedDate.year &&
                    currentDate.month == _calculatedDate.month &&
                    currentDate.day == _calculatedDate.day;

                final holidayKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
                final isHoliday = holidays.contains(holidayKey);

                Color bgColor = Colors.white;
                Color textColor = Colors.black;

                if (isReferenceSelected) {
                  // Data de referência selecionada: azul com letras brancas
                  bgColor = Colors.blue;
                  textColor = Colors.white;
                } else if (isCalculated) {
                  // Data calculada: roxo com letras brancas
                  bgColor = Colors.purple;
                  textColor = Colors.white;
                } else if (isHoliday) {
                  // Feriados sempre verde com letras brancas
                  bgColor = Colors.green;
                  textColor = Colors.white;
                } else if (currentDate.weekday == 7) { // Domingo
                  bgColor = Colors.red;
                  textColor = Colors.white;
                } else if (currentDate.weekday == 6) { // Sábado
                  bgColor = const Color(0xFFEF9A9A);
                  textColor = Colors.white;
                }

                return GestureDetector(
                  onTap: isReference ? () {
                    setState(() {
                      _referenceDate = currentDate;
                      _calculateDate();
                    });
                  } : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? 500 : 900,
        maxHeight: isMobile ? 800 : 700,
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título com dropdown de cidade e botão de PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cidade',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String>(
                        value: _selectedCityName,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'Caçapava', child: Text('Caçapava')),
                          DropdownMenuItem(value: 'Igaratá', child: Text('Igaratá')),
                          DropdownMenuItem(value: 'Jacareí', child: Text('Jacareí')),
                          DropdownMenuItem(value: 'Jambeiro', child: Text('Jambeiro')),
                          DropdownMenuItem(value: 'Monteiro Lobato', child: Text('Monteiro Lobato')),
                          DropdownMenuItem(value: 'Paraibuna', child: Text('Paraibuna')),
                          DropdownMenuItem(value: 'Santa Branca', child: Text('Santa Branca')),
                          DropdownMenuItem(value: 'São José dos Campos', child: Text('São José dos Campos')),
                          DropdownMenuItem(value: 'Campos do Jordão', child: Text('Campos do Jordão')),
                          DropdownMenuItem(value: 'Lagoinha', child: Text('Lagoinha')),
                          DropdownMenuItem(value: 'Natividade da Serra', child: Text('Natividade da Serra')),
                          DropdownMenuItem(value: 'Pindamonhangaba', child: Text('Pindamonhangaba')),
                          DropdownMenuItem(value: 'Redenção da Serra', child: Text('Redenção da Serra')),
                          DropdownMenuItem(value: 'Santo Antônio do Pinhal', child: Text('Santo Antônio do Pinhal')),
                          DropdownMenuItem(value: 'São Bento do Sapucaí', child: Text('São Bento do Sapucaí')),
                          DropdownMenuItem(value: 'São Luiz do Paraitinga', child: Text('São Luiz do Paraitinga')),
                          DropdownMenuItem(value: 'Taubaté', child: Text('Taubaté')),
                          DropdownMenuItem(value: 'Tremembé', child: Text('Tremembé')),
                          DropdownMenuItem(value: 'Aparecida', child: Text('Aparecida')),
                          DropdownMenuItem(value: 'Cachoeira Paulista', child: Text('Cachoeira Paulista')),
                          DropdownMenuItem(value: 'Canas', child: Text('Canas')),
                          DropdownMenuItem(value: 'Cunha', child: Text('Cunha')),
                          DropdownMenuItem(value: 'Guaratinguetá', child: Text('Guaratinguetá')),
                          DropdownMenuItem(value: 'Lorena', child: Text('Lorena')),
                          DropdownMenuItem(value: 'Piquete', child: Text('Piquete')),
                          DropdownMenuItem(value: 'Potim', child: Text('Potim')),
                          DropdownMenuItem(value: 'Roseira', child: Text('Roseira')),
                          DropdownMenuItem(value: 'Arapeí', child: Text('Arapeí')),
                          DropdownMenuItem(value: 'Areias', child: Text('Areias')),
                          DropdownMenuItem(value: 'Bananal', child: Text('Bananal')),
                          DropdownMenuItem(value: 'Cruzeiro', child: Text('Cruzeiro')),
                          DropdownMenuItem(value: 'Lavrinhas', child: Text('Lavrinhas')),
                          DropdownMenuItem(value: 'Queluz', child: Text('Queluz')),
                          DropdownMenuItem(value: 'São José do Barreiro', child: Text('São José do Barreiro')),
                          DropdownMenuItem(value: 'Silveiras', child: Text('Silveiras')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCityName = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  color: Colors.grey[600],
                  iconSize: 20,
                  tooltip: 'Exportar PDF',
                  onPressed: () {
                    final pdfData = _generatePdfData();
                    _showPdfPreview(context, pdfData);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dois painéis de calendário (referência esquerda, calculado direita)
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 400),
                      child: _buildCalendarPanel(_referenceDate, isReference: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 400),
                      child: _buildCalendarPanel(_calculatedDate, isReference: false),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 400),
                    child: _buildCalendarPanel(_referenceDate, isReference: true),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 400),
                    child: _buildCalendarPanel(_calculatedDate, isReference: false),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Seção de cálculo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calcular Dias',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Input de quantidade de dias com máscara 99999
                        Expanded(
                          flex: 2,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantos dias?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              hintText: '0',
                            ),
                            controller: _daysController,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            onChanged: (value) {
                              // Calcular ao mudar o valor
                              setState(() {
                                _daysCount = int.tryParse(value) ?? 0;
                                _calculateDate();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Dropdown tipo de dias
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _dayType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'uteis',
                                child: Text('Úteis'),
                              ),
                              DropdownMenuItem(
                                value: 'totais',
                                child: Text('Corridos'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _dayType = value ?? 'uteis';
                                _calculateDate();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Dropdown direção
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _direction,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'frente',
                                child: Text('Para frente'),
                              ),
                              DropdownMenuItem(
                                value: 'tras',
                                child: Text('Para trás'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _direction = value ?? 'frente';
                                _calculateDate();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Data calculada resultado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Calculada:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy - EEEE', 'pt_BR')
                                .format(_calculatedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botão fechar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
