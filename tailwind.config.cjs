/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./index.html', './src/**/*.js', './src/**/*.css'],
  prefix: 'tw-',
  corePlugins: { preflight: false },
  theme: {
    extend: {
      colors: {
        forest: { 950: '#082d22', 900: '#0f3e2f', 800: '#0f4c38' },
        highway: { 500: '#e4b84a' }
      },
      spacing: { control: 'var(--control-height)' },
      borderRadius: { doh: 'var(--radius-md)' }
    }
  },
  plugins: []
};
