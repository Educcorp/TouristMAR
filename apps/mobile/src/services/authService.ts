import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_URL } from './config';

const TOKEN_KEY = 'touristmar.token';

export interface AuthUser {
  id: string;
  email: string;
  name: string;
  role: string;
  avatarUrl: string | null;
}

interface AuthResponse {
  token: string;
  user: AuthUser;
}

async function handleAuthResponse(res: Response): Promise<AuthResponse> {
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data?.error ?? 'Error de autenticación');
  }
  await AsyncStorage.setItem(TOKEN_KEY, data.token);
  return data as AuthResponse;
}

export async function loginWithEmail(
  email: string,
  password: string,
): Promise<AuthResponse> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  return handleAuthResponse(res);
}

export async function registerWithEmail(
  email: string,
  password: string,
  name: string,
): Promise<AuthResponse> {
  const res = await fetch(`${API_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, name }),
  });
  return handleAuthResponse(res);
}

export async function loginWithGoogleIdToken(
  idToken: string,
): Promise<AuthResponse> {
  const res = await fetch(`${API_URL}/auth/google/mobile`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  return handleAuthResponse(res);
}

export async function getStoredToken(): Promise<string | null> {
  return AsyncStorage.getItem(TOKEN_KEY);
}

export async function clearStoredToken(): Promise<void> {
  await AsyncStorage.removeItem(TOKEN_KEY);
}
