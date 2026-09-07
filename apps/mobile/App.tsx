/**
 * TouristMAR mobile - MVP temporal.
 * Login (correo/contraseña o Google) -> pantalla con boton para abrir la
 * camara AR. Unity se lanza como su propia Activity de Android (no
 * embebido), ver src/ar-bridge/arLauncher.ts.
 * Sin navegacion todavia, un estado simple alcanza para este MVP.
 */
import React, { useEffect, useState } from 'react';
import { StatusBar } from 'react-native';
import LoginScreen from './src/screens/LoginScreen';
import ArHomeScreen from './src/screens/ArHomeScreen';
import { getStoredToken } from './src/services/authService';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [checkingSession, setCheckingSession] = useState(true);

  useEffect(() => {
    getStoredToken().then(token => {
      setIsLoggedIn(Boolean(token));
      setCheckingSession(false);
    });
  }, []);

  if (checkingSession) {
    return null;
  }

  return (
    <>
      <StatusBar hidden={isLoggedIn} barStyle="light-content" />
      {isLoggedIn ? (
        <ArHomeScreen onLogout={() => setIsLoggedIn(false)} />
      ) : (
        <LoginScreen onLoginSuccess={() => setIsLoggedIn(true)} />
      )}
    </>
  );
}

export default App;
