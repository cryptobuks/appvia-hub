import '../stylesheets/application.scss';

import Rails from 'rails-ujs';
import Turbolinks from 'turbolinks';

import LocalTime from 'local-time';

import 'bootstrap/dist/js/bootstrap';
import 'bootstrap-select';
import 'data-confirm-modal';

import '../gem-dependencies.js.erb';

import '../controllers';

Rails.start();
Turbolinks.start();
LocalTime.start();

/* eslint-disable no-undef */

document.addEventListener('turbolinks:load', () => {
  $(function tooltipActivation() {
    $('[data-toggle="tooltip"]').tooltip();
  });
});

// Make bootstrap-select work with Turbolinks
document.addEventListener('turbolinks:load', () => {
  $(window).trigger('load.bs.select.data-api');
});

/* eslint-enable no-undef */
