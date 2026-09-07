/**
 * URL base del backend (apps/backend), ya desplegado en Railway. Apunta
 * directo a produccion, asi que el login funciona sin depender de que el
 * backend este corriendo local ni de la red del celular.
 */
export const API_URL = 'https://touristmar-production.up.railway.app/api';

/**
 * Google OAuth Client ID de tipo "Web application" (el mismo que usa el
 * backend como GOOGLE_CLIENT_ID). Requerido por el SDK nativo de Google
 * Sign-In como "webClientId" para que el idToken que emite sea verificable
 * en el backend. Reemplazar con el valor real de Google Cloud Console.
 */
export const GOOGLE_WEB_CLIENT_ID = '794250368043-kd95m171jjljd9nvdhqv0cfi6qma3k6s.apps.googleusercontent.com';
