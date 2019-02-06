const { environment } = require('@rails/webpacker');
const webpack = require('webpack');
const vue = require('./loaders/vue');
const erb = require('./loaders/erb');

environment.loaders.append('vue', vue);
environment.loaders.append('erb', erb);

environment.plugins.append(
  'Provide',
  new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    Popper: ['popper.js', 'default']
  })
);

module.exports = environment;
