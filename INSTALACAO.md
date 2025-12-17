# 📦 Guia de Instalação

## Passo 1: Extrair Arquivos

Extraia o conteúdo do ZIP para uma pasta de sua escolha.

## Passo 2: Instalar Flutter

Se ainda não tem o Flutter instalado:
https://flutter.dev/docs/get-started/install

## Passo 3: Instalar Dependências

Abra o terminal na pasta do projeto e execute:

```bash
flutter pub get
```

## Passo 4: Executar

```bash
flutter run
```

Escolha o dispositivo (Chrome para web, Windows para desktop, etc)

## Passo 5: Compilar (Opcional)

Para Windows:
```bash
flutter build windows
```

Para Android:
```bash
flutter build apk
```

Para iOS:
```bash
flutter build ios
```

## 🎉 Pronto!

O aplicativo está rodando!

## ⚠️ Troubleshooting

### Erro: "SDK não encontrado"
Execute: `flutter doctor` e siga as instruções

### Erro: "Dependências não encontradas"
Execute: `flutter pub get` novamente

### Erro ao compilar
Certifique-se de ter todas as ferramentas necessárias:
- Windows: Visual Studio 2022
- Android: Android Studio
- iOS: Xcode (apenas em macOS)
