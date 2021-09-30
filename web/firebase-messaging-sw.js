importScripts('https://www.gstatic.com/firebasejs/8.6.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.6.1/firebase-messaging.js');

const firebaseConfig = {
    apiKey: "AIzaSyC5YinQZ06MNax0rqD-shfJoA_iRFNQRP8",
    authDomain: "flutterweb-6b57b.firebaseapp.com",
    projectId: "flutterweb-6b57b",
    storageBucket: "flutterweb-6b57b.appspot.com",
    messagingSenderId: "141741420506",
    appId: "1:141741420506:web:88cdf8c7006a8a0c045ae3",
    measurementId: "G-6C6R0S0PLC"
  };
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();
  messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            return registration.showNotification("New Message");
        });
    return promiseChain;
});
messaging.onBackgroundMessage((message) => {
    console.log("onBackgroundMessage", message);
  });
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});