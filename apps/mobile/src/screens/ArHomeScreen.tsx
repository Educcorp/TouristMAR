import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { colors } from '../theme/colors';
import { openArActivity } from '../ar-bridge/arLauncher';
import { clearStoredToken } from '../services/authService';

interface Props {
  onLogout: () => void;
}

export default function ArHomeScreen({ onLogout }: Props) {
  async function handleLogout() {
    await clearStoredToken();
    onLogout();
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Sesión iniciada</Text>
      <Text style={styles.subtitle}>Toca el botón para abrir la cámara AR</Text>

      <TouchableOpacity style={styles.primaryButton} onPress={openArActivity}>
        <Text style={styles.primaryButtonText}>Abrir cámara AR</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
        <Text style={styles.logoutButtonText}>Cerrar sesión</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.panelNavy,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  title: {
    color: colors.white,
    fontSize: 24,
    fontWeight: '600',
    marginBottom: 8,
  },
  subtitle: {
    color: colors.slate400,
    fontSize: 14,
    marginBottom: 32,
    textAlign: 'center',
  },
  primaryButton: {
    backgroundColor: colors.brandTeal,
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: 12,
    marginBottom: 16,
  },
  primaryButtonText: {
    color: colors.panelNavy,
    fontSize: 16,
    fontWeight: '700',
  },
  logoutButton: {
    paddingVertical: 10,
    paddingHorizontal: 24,
  },
  logoutButtonText: {
    color: colors.slate400,
    fontSize: 14,
  },
});
