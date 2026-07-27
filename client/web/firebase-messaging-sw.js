importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAVMxzD2fxQPX2DIaYQOdb1offXp0wxTEQ',
  authDomain: 'vesper-ai-37d6f.firebaseapp.com',
  projectId: 'vesper-ai-37d6f',
  storageBucket: 'vesper-ai-37d6f.firebasestorage.app',
  messagingSenderId: '862600156615',
  appId: '1:862600156615:web:9a657a00d2a80b6475b5e2',
});

const messaging = firebase.messaging();