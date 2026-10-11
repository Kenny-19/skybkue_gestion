#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Une seule instance par session Windows.
  //
  // Le 9 octobre 2026, le poste DESKTOP-DPJ4R46 a eu DEUX Skyblue ouverts
  // en même temps. Le premier encaissait normalement ; le second, caché
  // derrière, n'a jamais pu ouvrir la base (« database is locked ») et a
  // remonté plus de 600 erreurs en dix-sept heures. Deux applications sur
  // la même caisse, c'est aussi deux synchronisations qui se marchent
  // dessus. Un second lancement ramène donc la fenêtre déjà ouverte au
  // premier plan, et s'arrête là.
  //
  // Le mutex disparaît avec le processus : après un plantage ou le
  // taskkill de l'installeur, le lancement suivant repart normalement.
  HANDLE instance_unique =
      ::CreateMutexW(nullptr, TRUE, L"Local\\Skyblue.Ventes.InstanceUnique");
  if (instance_unique != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND deja = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Skyblue");
    if (deja != nullptr) {
      if (::IsIconic(deja)) ::ShowWindow(deja, SW_RESTORE);
      ::SetForegroundWindow(deja);
    }
    ::CloseHandle(instance_unique);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Taille initiale + centrage sur l'écran principal.
  // Taille initiale adaptée aux écrans 1024×768 (le POS de la maison).
  // Reste redimensionnable jusqu'au min imposé par WM_GETMINMAXINFO.
  Win32Window::Size size(1024, 720);
  RECT wa{};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &wa, 0);
  const LONG screenW = wa.right - wa.left;
  const LONG screenH = wa.bottom - wa.top;
  Win32Window::Point origin(
      wa.left + (screenW - static_cast<LONG>(size.width)) / 2,
      wa.top + (screenH - static_cast<LONG>(size.height)) / 2);
  if (!window.Create(L"Skyblue", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
