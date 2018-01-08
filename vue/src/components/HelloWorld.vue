<template>
<div class="hello">

</div>
</template>

<script>
export default {
  name: 'HelloWorld',
  data() {
    return {
      msg: 'Welcome to Your Vue.js App'
    }
  },
  created: function() {
    const socket = new WebSocket('ws://localhost:8181')
    socket.addEventListener('open', function(event) {
      socket.send('Hello Server!');
    });
    socket.addEventListener('message', function(event) {
      console.log('Message from server', event.data);
    });
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h1,
h2 {
  font-weight: normal;
}

ul {
  list-style-type: none;
  padding: 0;
}

li {
  display: inline-block;
  margin: 0 10px;
}

a {
  color: #42b983;
}
</style>
