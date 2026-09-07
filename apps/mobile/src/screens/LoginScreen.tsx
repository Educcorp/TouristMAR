import React, { useState } from 'react';
import {
  ActivityIndicator,
  ImageBackground,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import {
  Eye,
  EyeOff,
  FerrisWheel,
  Footprints,
  Lock,
  Mail,
  Mountain,
  Umbrella,
  User,
  UtensilsCrossed,
  Waves,
  type LucideIcon,
} from 'lucide-react-native';
import { GoogleSignin } from '@react-native-google-signin/google-signin';
import { GOOGLE_WEB_CLIENT_ID } from '../services/config';
import {
  loginWithEmail,
  loginWithGoogleIdToken,
  registerWithEmail,
} from '../services/authService';
import GoogleGLogo from '../components/GoogleGLogo';
import { colors } from '../theme/colors';

GoogleSignin.configure({ webClientId: GOOGLE_WEB_CLIENT_ID });

const serifFont = Platform.select({ ios: 'Georgia', android: 'serif', default: 'serif' });

const categories: { label: string; icon: LucideIcon }[] = [
  { label: 'Playas', icon: Umbrella },
  { label: 'Senderismo', icon: Footprints },
  { label: 'Restaurantes', icon: UtensilsCrossed },
  { label: 'Miradores', icon: Mountain },
  { label: 'Recreación', icon: FerrisWheel },
];

const stats = [
  { value: '80+', label: 'Lugares' },
  { value: '4.8★', label: 'Valoración media' },
  { value: '360°', label: 'Fotos inmersivas' },
];

type Mode = 'login' | 'register';

interface Props {
  onLoginSuccess: () => void;
}

export default function LoginScreen({ onLoginSuccess }: Props) {
  const [mode, setMode] = useState<Mode>('login');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit() {
    setError(null);
    setLoading(true);
    try {
      if (mode === 'login') {
        await loginWithEmail(email.trim(), password);
      } else {
        await registerWithEmail(email.trim(), password, name.trim());
      }
      onLoginSuccess();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  async function handleGoogleLogin() {
    setError(null);
    setLoading(true);
    try {
      await GoogleSignin.hasPlayServices();
      const response = await GoogleSignin.signIn();
      if (response.type !== 'success' || !response.data.idToken) {
        throw new Error('No se recibió el idToken de Google');
      }
      await loginWithGoogleIdToken(response.data.idToken);
      onLoginSuccess();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  function toggleMode() {
    setError(null);
    setMode(current => (current === 'login' ? 'register' : 'login'));
  }

  return (
    <ScrollView style={styles.root} contentContainerStyle={styles.scrollContent}>
      <ImageBackground
        source={require('../assets/hero-manzanillo.jpg')}
        style={styles.hero}
        resizeMode="cover"
      >
        <View style={styles.heroOverlay} />

        <View style={styles.brandRow}>
          <View style={styles.brandBadge}>
            <Waves size={18} color={colors.panelNavy} />
          </View>
          <Text style={styles.brandText}>TOURISMAR</Text>
        </View>

        <View style={styles.heroContent}>
          <Text style={styles.heroEyebrow}>MANZANILLO · COLIMA</Text>
          <Text style={styles.heroTitle}>Descubre el Pacífico Mexicano</Text>
          <Text style={styles.heroDescription}>
            Playas, senderos de hiking, miradores y sabores locales — todo centralizado para
            que explores Manzanillo como nunca antes.
          </Text>

          <View style={styles.pillsRow}>
            {categories.map(category => (
              <View key={category.label} style={styles.pill}>
                <category.icon size={13} color={colors.white} />
                <Text style={styles.pillText}>{category.label}</Text>
              </View>
            ))}
          </View>

          <View style={styles.statsRow}>
            {stats.map(stat => (
              <View key={stat.label} style={styles.statItem}>
                <Text style={styles.statValue}>{stat.value}</Text>
                <Text style={styles.statLabel}>{stat.label}</Text>
              </View>
            ))}
          </View>
        </View>
      </ImageBackground>

      <View style={styles.formSection}>
        <Text style={styles.formTitle}>
          {mode === 'login' ? 'Bienvenido de vuelta' : 'Crea tu cuenta'}
        </Text>
        <Text style={styles.formSubtitle}>
          {mode === 'login'
            ? 'Inicia sesión para seguir explorando Manzanillo'
            : 'Regístrate para guardar tus lugares favoritos'}
        </Text>

        {mode === 'register' && (
          <View style={styles.field}>
            <Text style={styles.label}>Nombre</Text>
            <View style={styles.inputWrapper}>
              <User size={16} color={colors.slate500} style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder="Tu nombre"
                placeholderTextColor={colors.slate500}
                autoCapitalize="words"
                value={name}
                onChangeText={setName}
              />
            </View>
          </View>
        )}

        <View style={styles.field}>
          <Text style={styles.label}>Correo electrónico</Text>
          <View style={styles.inputWrapper}>
            <Mail size={16} color={colors.slate500} style={styles.inputIcon} />
            <TextInput
              style={styles.input}
              placeholder="tu@correo.com"
              placeholderTextColor={colors.slate500}
              autoCapitalize="none"
              keyboardType="email-address"
              value={email}
              onChangeText={setEmail}
            />
          </View>
        </View>

        <View style={styles.field}>
          <Text style={styles.label}>Contraseña</Text>
          <View style={styles.inputWrapper}>
            <Lock size={16} color={colors.slate500} style={styles.inputIcon} />
            <TextInput
              style={styles.input}
              placeholder="••••••••"
              placeholderTextColor={colors.slate500}
              secureTextEntry={!showPassword}
              value={password}
              onChangeText={setPassword}
            />
            <TouchableOpacity
              onPress={() => setShowPassword(value => !value)}
              style={styles.eyeButton}
            >
              {showPassword ? (
                <EyeOff size={16} color={colors.slate500} />
              ) : (
                <Eye size={16} color={colors.slate500} />
              )}
            </TouchableOpacity>
          </View>
        </View>

        {error ? <Text style={styles.error}>{error}</Text> : null}

        {loading ? (
          <ActivityIndicator color={colors.brandTeal} style={styles.loader} />
        ) : (
          <>
            <View style={styles.dividerRow}>
              <View style={styles.dividerLine} />
              <Text style={styles.dividerText}>o continúa con Google</Text>
              <View style={styles.dividerLine} />
            </View>

            <TouchableOpacity style={styles.googleButton} onPress={handleGoogleLogin}>
              <GoogleGLogo size={18} />
              <Text style={styles.googleButtonText}>Continuar con Google</Text>
            </TouchableOpacity>

            <TouchableOpacity style={styles.primaryButton} onPress={handleSubmit}>
              <Text style={styles.primaryButtonText}>
                {mode === 'login' ? 'Iniciar sesión' : 'Crear cuenta'}
              </Text>
            </TouchableOpacity>
          </>
        )}

        <TouchableOpacity onPress={toggleMode} style={styles.toggleRow}>
          <Text style={styles.toggleText}>
            {mode === 'login' ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? '}
            <Text style={styles.toggleLink}>
              {mode === 'login' ? 'Regístrate gratis' : 'Inicia sesión'}
            </Text>
          </Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.panelNavy,
  },
  scrollContent: {
    flexGrow: 1,
  },
  hero: {
    minHeight: 380,
    justifyContent: 'flex-end',
  },
  heroOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(11,18,32,0.45)',
  },
  brandRow: {
    position: 'absolute',
    top: 24,
    left: 24,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  brandBadge: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: colors.brandTeal,
    alignItems: 'center',
    justifyContent: 'center',
  },
  brandText: {
    color: colors.white,
    fontWeight: '600',
    fontSize: 13,
    letterSpacing: 3,
  },
  heroContent: {
    padding: 24,
    paddingTop: 40,
    backgroundColor: 'rgba(11,18,32,0.55)',
  },
  heroEyebrow: {
    color: colors.brandTeal,
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 3,
    marginBottom: 8,
  },
  heroTitle: {
    color: colors.white,
    fontSize: 30,
    lineHeight: 36,
    fontFamily: serifFont,
    marginBottom: 10,
  },
  heroDescription: {
    color: colors.slate300,
    fontSize: 13,
    lineHeight: 19,
    marginBottom: 16,
  },
  pillsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 16,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    backgroundColor: 'rgba(0,0,0,0.3)',
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  pillText: {
    color: colors.white,
    fontSize: 11,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 28,
    borderTopWidth: 1,
    borderTopColor: colors.borderSubtle,
    paddingTop: 14,
  },
  statItem: {},
  statValue: {
    color: colors.white,
    fontSize: 18,
    fontWeight: '600',
  },
  statLabel: {
    color: colors.slate400,
    fontSize: 11,
  },
  formSection: {
    padding: 24,
    paddingTop: 32,
    paddingBottom: 48,
  },
  formTitle: {
    color: colors.white,
    fontSize: 26,
    fontFamily: serifFont,
    marginBottom: 4,
  },
  formSubtitle: {
    color: colors.slate400,
    fontSize: 13,
    marginBottom: 24,
  },
  field: {
    marginBottom: 16,
  },
  label: {
    color: colors.slate300,
    fontSize: 13,
    marginBottom: 6,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.borderSubtle,
    backgroundColor: colors.panelNavySoft,
    paddingHorizontal: 12,
  },
  inputIcon: {
    marginRight: 8,
  },
  input: {
    flex: 1,
    color: colors.white,
    fontSize: 14,
    paddingVertical: 12,
  },
  eyeButton: {
    padding: 4,
  },
  error: {
    color: colors.red400,
    fontSize: 13,
    marginBottom: 12,
    textAlign: 'center',
  },
  loader: {
    marginVertical: 16,
  },
  dividerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 20,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: colors.borderSubtle,
  },
  dividerText: {
    color: colors.slate500,
    fontSize: 11,
  },
  googleButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    backgroundColor: colors.white,
    borderRadius: 10,
    paddingVertical: 13,
    marginBottom: 12,
  },
  googleButtonText: {
    color: colors.slate800,
    fontSize: 14,
    fontWeight: '500',
  },
  primaryButton: {
    backgroundColor: colors.brandTeal,
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 20,
  },
  primaryButtonText: {
    color: colors.panelNavy,
    fontSize: 14,
    fontWeight: '600',
  },
  toggleRow: {
    alignItems: 'center',
  },
  toggleText: {
    color: colors.slate400,
    fontSize: 13,
  },
  toggleLink: {
    color: colors.brandTeal,
    fontWeight: '600',
  },
});
