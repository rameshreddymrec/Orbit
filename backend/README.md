# BlackHole Backend Proxy - Deployment Guide

## What This Does

This backend server acts as a proxy between your Flutter web app and Jiosaavn. Since Jiosaavn blocks browser requests but allows server requests, this solves the "403 Forbidden" issue.

## Quick Start (Local Testing)

1. **Install dependencies:**
```bash
cd backend
npm install
```

2. **Start the server:**
```bash
npm start
```

The server will run on `http://localhost:3000`

3. **Test it:**
Open `http://localhost:3000` in your browser - you should see a health check message.

## Deploy to Vercel (Free, Recommended)

### Step 1: Install Vercel CLI
```bash
npm install -g vercel
```

### Step 2: Deploy
```bash
cd backend
vercel
```

Follow the prompts:
- **Set up and deploy?** → Yes
- **Which scope?** → Your account
- **Link to existing project?** → No
- **Project name?** → blackhole-proxy (or any name)
- **Directory?** → ./ (current directory)
- **Override settings?** → No

### Step 3: Get Your URL

After deployment, Vercel will give you a URL like:
```
https://blackhole-proxy-xxxxx.vercel.app
```

**Copy this URL!** You'll need it for the next step.

## Update Flutter App

Once deployed, update `lib/APIs/api.dart`:

Find this line (around line 95):
```dart
url = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(url.toString())}');
```

Replace with:
```dart
url = Uri.parse('https://YOUR-VERCEL-URL.vercel.app/api/jiosaavn?url=${Uri.encodeComponent(url.toString())}');
```

**Example:**
```dart
url = Uri.parse('https://blackhole-proxy-abc123.vercel.app/api/jiosaavn?url=${Uri.encodeComponent(url.toString())}');
```

## Verify It Works

1. Run your Flutter app: `flutter run -d chrome`
2. Check the browser console - you should see successful API responses
3. The home screen should load real Jiosaavn music!

## Alternative: Deploy to Railway

If you prefer Railway over Vercel:

1. Go to [railway.app](https://railway.app)
2. Click "Start a New Project"
3. Select "Deploy from GitHub repo"
4. Connect your repo and select the `backend` folder
5. Railway will auto-detect Node.js and deploy

## Troubleshooting

**"Module not found" error:**
- Make sure you ran `npm install` in the backend directory

**CORS errors:**
- The server has CORS enabled for all origins by default
- If you want to restrict it, edit `server.js` line 9

**Deployment fails:**
- Ensure Node.js version is 18+ (check `package.json` engines)
- Check Vercel/Railway logs for specific errors

**Still getting 403:**
- Verify the Flutter app is using the correct backend URL
- Check that the backend is actually running (visit the health check URL)
