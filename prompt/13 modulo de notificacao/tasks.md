# Guia de Tarefas para Agente - Background Video Generation

## ESCOPO DO PROJETO

### O QUE ESTÁ SENDO CONSTRUÍDO:
Um sistema robusto de **geração de vídeo em background** que permite ao usuário:
- Iniciar a criação de um vídeo (combinando áudio + imagens)
- Minimizar o aplicativo e usar outros apps enquanto o vídeo é processado
- Receber notificações em tempo real sobre o progresso da geração
- Controlar o processo diretamente pelas notificações (cancelar, abrir resultado, compartilhar)
- Ter garantia de que o processo continua mesmo se o app for fechado

### PROBLEMA QUE RESOLVE:
**ANTES:** Usuário precisava manter o app aberto durante toda a geração do vídeo (que pode demorar vários minutos), não podendo usar o dispositivo para outras tarefas.

**DEPOIS:** Usuário inicia a geração, pode usar qualquer outro app, e é notificado quando o vídeo estiver pronto, com opções diretas para visualizar ou compartilhar.

### FUNCIONALIDADES PRINCIPAIS:
1. **Execução em Background Robusta:**
   - Processamento continua mesmo com app minimizado ou fechado
   - Usa foreground service para garantir execução
   - Isolates dedicados para não travar a interface

2. **Notificações Interativas (estilo Uber):**
   - Progresso em tempo real (0% a 100%)
   - Estados visuais diferentes (preparando, processando, finalizando, concluído)
   - Botões de ação direta (cancelar, abrir vídeo, compartilhar)
   - Ícones e cores apropriados para cada estado

3. **Integração Transparente:**
   - Mantém funcionalidade original do app intacta
   - Adiciona opção "Gerar em Background" na tela existente
   - Indicadores visuais discretos de progresso
   - Zero impacto na experiência atual

4. **Robustez e Recuperação:**
   - Recupera tarefas ativas após restart do app
   - Tratamento de erros com opções de retry
   - Cleanup automático de recursos
   - Persistência de estado em caso de falhas

### EXPERIÊNCIA DO USUÁRIO ESPERADA:
1. Usuário configura vídeo normalmente (áudio + imagens)
2. Na tela de geração, escolhe "GERAR EM BACKGROUND" em vez do botão normal
3. Recebe confirmação e pode imediatamente usar outros apps
4. Vê notificação persistente com progresso atualizado em tempo real
5. Quando concluído, recebe notificação com opções para abrir/compartilhar
6. Todo o processo é transparente e não requer atenção constante

### TECNOLOGIAS ENVOLVIDAS:
- **Flutter Background Service:** Execução contínua
- **Flutter Local Notifications:** Notificações interativas
- **Isolates:** Processamento pesado sem travar UI
- **Shared Preferences:** Persistência de estado
- **Foreground Service Android:** Garantia de execução

### RESULTADO FINAL ESPERADO:
Sistema profissional de background processing similar ao que apps como Uber, WhatsApp e YouTube usam para uploads/downloads, onde o usuário inicia uma operação e pode esquecer dela, sendo notificado automaticamente quando concluída.

## FASE 1: PREPARAÇÃO DO AMBIENTE

### TAREFA 1: Atualizar Dependências do Projeto
**Localização:** `pubspec.yaml`
**Objetivo:** Adicionar bibliotecas necessárias para background e notificações
**Ações:**
1. Abrir arquivo `pubspec.yaml`
2. Na seção `dependencies:`, adicionar as seguintes linhas:
   - `flutter_local_notifications: ^17.0.0`
   - `flutter_background_service: ^5.0.0`
   - `workmanager: ^0.5.2`
   - `shared_preferences: ^2.2.2`
   - `flutter_isolate: ^2.0.4`
3. Salvar arquivo
4. Executar comando: `flutter pub get`
**Verificação:** Comando deve executar sem erros e dependências devem ser baixadas

---

### TAREFA 2: Configurar Permissões Android
**Localização:** `android/app/src/main/AndroidManifest.xml`
**Objetivo:** Adicionar permissões para background service e notificações
**Ações:**
1. Abrir arquivo AndroidManifest.xml
2. Adicionar as seguintes permissões no topo (após `<manifest>` e antes de `<application>`):
   - `FOREGROUND_SERVICE`
   - `FOREGROUND_SERVICE_MEDIA_PROCESSING`
   - `POST_NOTIFICATIONS`
   - `VIBRATE`
   - `WAKE_LOCK`
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
   - `RECEIVE_BOOT_COMPLETED`
3. Dentro de `<application>`, adicionar declaração de serviço:
   - Serviço `BackgroundService` do flutter_background_service
   - Configurar como `foregroundServiceType="mediaProcessing"`
   - Configurar como `exported="false"`
4. Adicionar receiver para boot completed (opcional)
5. Salvar arquivo
**Verificação:** Arquivo deve ter sintaxe XML válida

---

### TAREFA 3: Criar Estrutura de Pastas
**Localização:** `lib/`
**Objetivo:** Organizar código do sistema de background
**Ações:**
1. Criar pasta `lib/services/background/`
2. Criar pasta `lib/models/background/`
3. Criar pasta `lib/widgets/background/`
4. Criar pasta `lib/utils/background/`
**Verificação:** Pastas devem existir e estar vazias

---

## FASE 2: MODELOS DE DADOS

### TAREFA 4: Criar Modelo de Tarefa em Background
**Localização:** `lib/models/background/background_task.dart`
**Objetivo:** Definir estrutura de dados para tarefas de geração de vídeo
**Funcionalidades necessárias:**
1. Classe `BackgroundTask` com propriedades:
   - `id` (String único)
   - `type` (enum: videoGeneration, imageProcessing, etc.)
   - `audioPath` (caminho do arquivo de áudio)
   - `imagePaths` (lista de caminhos de imagens)
   - `timestamps` (lista de timestamps em milissegundos)
   - `videoConfig` (configurações do vídeo)
   - `status` (enum: pending, processing, completed, failed, cancelled)
   - `progress` (double 0.0 a 1.0)
   - `currentStep` (string com etapa atual)
   - `outputPath` (caminho do vídeo gerado)
   - `error` (mensagem de erro, se houver)
   - `createdAt`, `updatedAt`, `completedAt` (timestamps)
2. Enum `BackgroundTaskType` com valores apropriados
3. Enum `TaskStatus` com todos os status possíveis
4. Métodos `toMap()`, `fromMap()`, `toJson()`, `fromJson()`
5. Método `copyWith()` para criar cópias modificadas
6. Propriedades calculadas: `isActive`, `isCompleted`, `isFailed`, etc.
**Verificação:** Classe deve compilar e ser serializável

---

### TAREFA 5: Criar Modelo de Estado de Progresso
**Localização:** `lib/models/background/progress_state.dart`
**Objetivo:** Definir estrutura para comunicação de progresso
**Funcionalidades necessárias:**
1. Classe `ProgressState` com propriedades:
   - `taskId` (identificador da tarefa)
   - `progress` (double 0.0 a 1.0)
   - `status` (TaskStatus)
   - `message` (string com mensagem atual)
   - `currentImage` (índice da imagem sendo processada)
   - `totalImages` (total de imagens)
   - `outputPath` (resultado final)
   - `error` (mensagem de erro)
   - `timestamp` (quando foi criado)
2. Métodos de serialização similar ao BackgroundTask
3. Propriedades calculadas para formatação:
   - `progressPercentage` (string "XX.X%")
   - `formattedProgress` (texto amigável)
   - `estimatedTimeRemaining` (estimativa)
4. Classe `VideoGenerationConfig` para configurações
**Verificação:** Classe deve compilar e ser usável para UI

---

## FASE 3: SISTEMA DE NOTIFICAÇÕES

### TAREFA 6: Implementar Gerenciador de Notificações
**Localização:** `lib/services/background/notification_manager.dart`
**Objetivo:** Criar sistema completo de notificações interativas
**Funcionalidades necessárias:**
1. Classe `NotificationManager` (singleton)
2. Enum `NotificationStatus` (preparing, processing, finalizing, completed, error)
3. Método `initialize()`:
   - Solicitar permissões de notificação
   - Criar canais de notificação Android
   - Configurar callbacks
4. Método `showProgressNotification()`:
   - Mostrar notificação com barra de progresso
   - Ícone baseado no status
   - Botão "Cancelar"
   - Atualização em tempo real
5. Método `updateProgressNotification()`:
   - Atualizar notificação existente
   - Manter ID consistente
6. Método `showCompletionNotification()`:
   - Notificação de sucesso
   - Botões "Abrir Vídeo" e "Compartilhar"
   - Som e vibração
7. Método `showErrorNotification()`:
   - Notificação de erro
   - Botões "Tentar Novamente" e "Ver Detalhes"
8. Métodos auxiliares:
   - `cancelNotification()`
   - `_onNotificationTapped()` (callback)
   - `_getIconForStatus()` (ícones por status)
   - `_buildProgressText()` (texto formatado)
9. Sistema de callbacks para ações das notificações
**Verificação:** Notificações devem aparecer e ser interativas

---

### TAREFA 7: Criar Ícones de Notificação (OPCIONAL)
**Localização:** `android/app/src/main/res/drawable/`
**Objetivo:** Adicionar ícones visuais para diferentes estados
**Ações:**
1. Criar arquivos XML com ícones simples:
   - `ic_gear.xml` (engrenagem para "preparando")
   - `ic_movie_camera.xml` (câmera para "processando")
   - `ic_save.xml` (disquete para "salvando")
   - `ic_check_circle.xml` (check para "sucesso")
   - `ic_error.xml` (X para "erro")
   - `ic_cancel.xml` (cancelar)
   - `ic_play.xml` (play)
   - `ic_share.xml` (compartilhar)
2. Usar vector drawables básicos do Material Design
**Nota:** Se não conseguir criar, usar ícones padrão do sistema
**Verificação:** Ícones devem aparecer nas notificações

---

## FASE 4: PROCESSAMENTO EM BACKGROUND

### TAREFA 8: Implementar Isolate de Geração de Vídeo
**Localização:** `lib/services/background/video_generation_isolate.dart`
**Objetivo:** Criar processamento isolado que não trava a UI
**Funcionalidades necessárias:**
1. Classe `VideoGenerationIsolate` com método estático `spawn()`
2. Função `_isolateEntryPoint()` como ponto de entrada
3. Classe interna `_IsolateVideoGenerator` com:
   - Gerenciamento de mensagens do main isolate
   - Integração com `QuickVideoEncoderService` existente
   - Envio de progresso via SendPort
   - Tratamento de cancelamento
4. Métodos de comunicação:
   - `handleMessage()` (processar comandos)
   - `_startGeneration()` (iniciar processamento)
   - `_generateVideo()` (lógica principal)
   - `_cancelGeneration()` (parar processo)
   - `_sendProgress()` (enviar atualizações)
   - `_sendCompleted()` (notificar conclusão)
   - `_sendError()` (notificar erro)
5. Sistema de comunicação bidirecional:
   - ReceivePort/SendPort
   - IsolateNameServer para registro
   - Protocolo de mensagens estruturado
6. Tratamento de erros robusto
7. Cleanup de recursos
**Verificação:** Isolate deve executar geração sem travar UI principal

---

## FASE 5: COORDENAÇÃO CENTRAL

### TAREFA 9: Implementar Gerenciador Principal de Background
**Localização:** `lib/services/background/background_service_manager.dart`
**Objetivo:** Coordenar todo o sistema de background
**Funcionalidades necessárias:**
1. Classe `BackgroundServiceManager` (singleton)
2. Método `initialize()`:
   - Inicializar NotificationManager
   - Configurar Flutter Background Service
   - Estabelecer comunicação com isolate
3. Método `startVideoGeneration()`:
   - Validar parâmetros de entrada
   - Criar BackgroundTask
   - Persistir tarefa em SharedPreferences
   - Spawnar isolate
   - Mostrar notificação inicial
   - Retornar ID da tarefa
4. Método `cancelVideoGeneration()`:
   - Enviar sinal de cancelamento para isolate
   - Limpar estado
   - Remover notificação
   - Atualizar UI
5. Sistema de comunicação:
   - `_setupIsolateCommunication()` (ReceivePort/SendPort)
   - `_handleIsolateMessage()` (processar mensagens do isolate)
   - Stream de progresso para UI
6. Tratamento de diferentes tipos de mensagem:
   - Progress updates
   - Task completion
   - Errors
   - Isolate ready
7. Persistência de estado:
   - `_saveTask()`, `_updateTaskProgress()`, `_updateTaskStatus()`
   - Recuperação após restart do app
   - `getActiveTasks()`
8. Cleanup e gerenciamento de recursos
9. Integração com Flutter Background Service
**Verificação:** Deve coordenar isolate, notificações e UI corretamente

---

## FASE 6: INTEGRAÇÃO COM UI

### TAREFA 10: Criar Serviço de Integração
**Localização:** `lib/services/background/integration_service.dart`
**Objetivo:** Fazer ponte entre sistema de background e UI existente
**Funcionalidades necessárias:**
1. Classe `BackgroundIntegrationService` (singleton)
2. Método `initialize()`:
   - Inicializar BackgroundServiceManager
   - Configurar callbacks de notificação
   - Escutar stream de progresso
   - Recuperar tarefas ativas
3. Método `startBackgroundVideoGeneration()`:
   - Integrar com ProjectProvider existente
   - Validar projeto (áudio + imagens)
   - Extrair dados do projeto
   - Chamar BackgroundServiceManager
   - Mostrar feedback na UI
4. Callbacks para ações de notificação:
   - Cancelar geração
   - Abrir vídeo gerado
   - Compartilhar vídeo
   - Tentar novamente
   - Mostrar detalhes de erro
5. Métodos auxiliares para UI:
   - `_showError()`, `_showSuccess()`, `_showInfo()`
   - Integração com SnackBar e Dialog
6. Recuperação de tarefas após restart
7. Gerenciamento de estado da tarefa atual
**Verificação:** Deve integrar perfeitamente com código existente

---

### TAREFA 11: Criar Widgets de Progresso
**Localização:** `lib/widgets/background/progress_widgets.dart`
**Objetivo:** Componentes visuais para mostrar progresso
**Funcionalidades necessárias:**
1. Widget `BackgroundProgressIndicator`:
   - Mostrar progresso atual em banner discreto
   - Botão para cancelar
   - Atualização em tempo real
   - Ocultar quando não há tarefas ativas
2. Widget `ActiveTasksList`:
   - Lista de todas as tarefas ativas
   - Card para cada tarefa com:
     - Status visual (ícone + cor)
     - Barra de progresso
     - Botões de ação (cancelar, abrir, compartilhar)
     - Informações detalhadas
3. Widget `BackgroundTasksScreen`:
   - Tela dedicada para monitorar tarefas
   - AppBar com ações (refresh)
   - Lista de tarefas ativas
4. Provider `BackgroundTaskProvider`:
   - Gerenciar estado das tarefas para UI
   - Notificar mudanças para widgets
   - Métodos para iniciar/cancelar tarefas
**Verificação:** Widgets devem renderizar e atualizar corretamente

---

## FASE 7: MODIFICAÇÃO DA UI EXISTENTE

### TAREFA 12: Atualizar Aplicação Principal
**Localização:** `lib/main.dart`
**Objetivo:** Inicializar sistema de background no app
**Ações:**
1. Importar `BackgroundIntegrationService`
2. No método `main()`, antes de `runApp()`:
   - Adicionar `await BackgroundVideoHelper.initializeBackgroundServices()`
3. No `MultiProvider`, adicionar:
   - `ChangeNotifierProvider(create: (context) => BackgroundTaskProvider())`
4. Garantir que `WidgetsFlutterBinding.ensureInitialized()` existe
**Verificação:** App deve iniciar sem erros com novos providers

---

### TAREFA 13: Adicionar Opção de Background na Tela de Geração
**Localização:** `lib/screens/video_generation_screen.dart`
**Objetivo:** Dar ao usuário a opção de gerar em background
**Ações:**
1. Importar `BackgroundIntegrationService`
2. Localizar onde está o botão "GERAR VÍDEO" existente
3. Antes dele, adicionar novo botão:
   - Texto: "GERAR EM BACKGROUND"
   - Ícone: cloud_upload
   - Cor: laranja
   - Ação: chamar `BackgroundIntegrationService.startBackgroundVideoGeneration()`
4. Adicionar espaçamento entre os botões
5. Manter funcionalidade original intacta
**Verificação:** Devem aparecer dois botões, ambos funcionais

---

### TAREFA 14: Adicionar Indicador Global de Progresso
**Localização:** `lib/screens/editor_screen.dart` (ou tela principal)
**Objetivo:** Mostrar progresso em qualquer lugar do app
**Ações:**
1. Importar widgets de background
2. Envolver o Scaffold principal com `BackgroundVideoHelper.wrapWithBackground()`
3. Isso adiciona automaticamente:
   - Banner de progresso quando há tarefa ativa
   - Botão para cancelar
   - Atualização em tempo real
4. Verificar que não interfere com layout existente
**Verificação:** Banner deve aparecer apenas quando há tarefa ativa

---

## FASE 8: TESTES E VALIDAÇÃO

### TAREFA 15: Teste de Compilação
**Objetivo:** Garantir que todo código compila corretamente
**Ações:**
1. Executar `flutter analyze`
2. Corrigir todos os erros e warnings
3. Executar `flutter build apk --debug` (ou equivalente)
4. Verificar que não há erros de import
**Verificação:** Zero erros de compilação

---

### TAREFA 16: Teste de Notificação Básica
**Objetivo:** Verificar sistema de notificações
**Ações:**
1. Em qualquer tela, adicionar temporariamente um botão de teste
2. No onPressed, chamar:
   - `NotificationManager().initialize()`
   - `showTestNotification()`
3. Executar app
4. Tocar no botão
5. Verificar se notificação aparece
6. Remover botão de teste
**Verificação:** Notificação deve aparecer na barra de status

---

### TAREFA 17: Teste de Fluxo Completo End-to-End
**Objetivo:** Validar funcionamento completo do sistema
**Ações:**
1. Iniciar app
2. Seguir fluxo normal:
   - Selecionar áudio
   - Adicionar imagens
   - Ir para tela de geração
3. Tocar em "GERAR EM BACKGROUND"
4. Verificar que notificação aparece
5. Minimizar app
6. Abrir outros aplicativos
7. Verificar que notificação atualiza progresso
8. Aguardar conclusão
9. Verificar notificação final
10. Tocar em "Abrir Vídeo"
**Verificação:** 
- Processo completo deve funcionar
- App não deve travar
- Notificações devem ser interativas
- Vídeo deve ser gerado corretamente

---

## INSTRUÇÕES CRÍTICAS PARA EXECUÇÃO

### ⚠️ ORDEM OBRIGATÓRIA:
- Executar tarefas EXATAMENTE na ordem numerada
- NUNCA pular uma tarefa
- SEMPRE verificar se tarefa anterior funcionou antes de continuar

### ⚠️ PONTOS DE PARADA OBRIGATÓRIOS:
- **Após Tarefa 5:** Modelos devem compilar (`flutter analyze`)
- **Após Tarefa 9:** Background service deve funcionar
- **Após Tarefa 12:** App deve iniciar sem erros
- **Após Tarefa 17:** Fluxo completo deve funcionar

### ⚠️ EM CASO DE ERRO:
1. PARAR imediatamente
2. IDENTIFICAR exatamente qual tarefa falhou
3. REPORTAR erro específico com detalhes
4. NÃO continuar até resolver o problema

### ⚠️ VERIFICAÇÕES ESSENCIAIS:
- Imports estão corretos
- Sintaxe está válida
- Permissões Android estão configuradas
- Dependências foram instaladas

### ⚠️ RESULTADO ESPERADO:
Sistema funcional de geração de vídeo em background com:
- Notificações interativas
- Progresso em tempo real
- Controle via notificação
- Execução robusta mesmo com app minimizado