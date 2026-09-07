import { NativeModules } from 'react-native';

/**
 * Lanza Unity (com.unity3d.player.UnityPlayerGameActivity) como su propia
 * Activity de Android, en vez de embeberlo como vista dentro de esta pantalla.
 * Ver ArLauncherModule.kt para el lado nativo.
 */
export function openArActivity() {
  NativeModules.ArLauncher?.open();
}
