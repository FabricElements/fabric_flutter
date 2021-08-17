/**
 * Welcome to your Workbox-powered service worker!
 *
 * You'll need to register this file in your web app and you should
 * disable HTTP caching for this file too.
 * See https://goo.gl/nhQhGp
 *
 * The rest of the code is auto-generated. Please don't update this file
 * directly; instead, make changes to your Workbox build configuration
 * and re-run your build process.
 * See https://goo.gl/2aRDsh
 */

import firebase from "firebase/app";
import "firebase/messaging";

// See: https://github.com/microsoft/TypeScript/issues/14877
/** @type {ServiceWorkerGlobalScope} */
let self;

function initInSw() {
  // [START messaging_init_in_sw]
  // Give the service worker access to Firebase Messaging.
  // Note that you can only use Firebase Messaging here. Other Firebase libraries
  // are not available in the service worker.
  importScripts('https://www.gstatic.com/firebasejs/8.8.1/firebase-app.js');
  importScripts('https://www.gstatic.com/firebasejs/8.8.1/firebase-messaging.js');

  // Initialize the Firebase app in the service worker by passing in
  // your app's Firebase config object.
  // https://firebase.google.com/docs/web/setup#config-object
  // Your web app's Firebase configuration
  importScripts('/javascript/firebase-init.js');

  // Retrieve an instance of Firebase Messaging so that it can handle background
  // messages.
  const messaging = firebase.messaging();
  // [END messaging_init_in_sw]
}

function onBackgroundMessage() {
  const messaging = firebase.messaging();

  // [START messaging_on_background_message]
  messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = 'Background Message Title';
    const notificationOptions = {
      body: 'Background Message body.',
      icon: '/firebase-logo.png'
    };

    self.registration.showNotification(notificationTitle,
        notificationOptions);
  });
  // [END messaging_on_background_message]
}

importScripts("https://storage.googleapis.com/workbox-cdn/releases/4.3.1/workbox-sw.js");

importScripts(
  "/precache-manifest.5d0c875a0bb027c6e366679ebd5aefbd.js"
);

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

workbox.core.clientsClaim();

/**
 * The workboxSW.precacheAndRoute() method efficiently caches and responds to
 * requests for URLs in the manifest.
 * See https://goo.gl/S9QRab
 */
self.__precacheManifest = [].concat(self.__precacheManifest || []);
workbox.precaching.precacheAndRoute(self.__precacheManifest, {});

workbox.routing.registerNavigationRoute(workbox.precaching.getCacheKeyForURL("/index.html"), {
  
  blacklist: [/^\/_/,/\/[^/?]+\.[^/]+$/],
});
