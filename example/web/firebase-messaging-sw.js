
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// Your web app's Firebase configuration
importScripts('/javascript/firebase-init.js');
// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((m) => {
    console.log("onBackgroundMessage", m);
});
