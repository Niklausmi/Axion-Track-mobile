importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
  apiKey: 'AIzaSyBAA3ROsFLzd9pjRnb009tYvh-dVIXo1vI',
  appId: '1:553634347311:web:5dfbe576cda06cdd2789da',
  messagingSenderId: '553634347311',
  projectId: 'fleetos-push',
  authDomain: 'fleetos-push.firebaseapp.com',
  storageBucket: 'fleetos-push.firebasestorage.app',
  measurementId: 'G-63W5K7CQWY',
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle,
    notificationOptions);
});
