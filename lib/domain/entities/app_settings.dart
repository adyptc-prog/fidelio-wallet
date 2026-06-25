enum ClientCardsViewMode { list, grid }

enum AppZoomMode { normal, large }

class AppSettings {
  const AppSettings({
    this.clientCardsViewMode = ClientCardsViewMode.list,
    this.zoomMode = AppZoomMode.normal,
    this.darkMode = false,
  });

  final ClientCardsViewMode clientCardsViewMode;
  final AppZoomMode zoomMode;
  final bool darkMode;
}
