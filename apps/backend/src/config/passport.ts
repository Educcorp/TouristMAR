import passport from 'passport'
import { Strategy as GoogleStrategy } from 'passport-google-oauth20'
import { env, isGoogleAuthEnabled } from './env'
import { findOrCreateGoogleUser } from '../modules/auth/auth.service'

if (isGoogleAuthEnabled) {
  passport.use(
    new GoogleStrategy(
      {
        clientID: env.GOOGLE_CLIENT_ID!,
        clientSecret: env.GOOGLE_CLIENT_SECRET!,
        callbackURL: env.GOOGLE_CALLBACK_URL!,
      },
      async (_accessToken, _refreshToken, profile, done) => {
        try {
          const user = await findOrCreateGoogleUser(profile)
          done(null, user)
        } catch (err) {
          done(err as Error)
        }
      },
    ),
  )
}

export { passport }
