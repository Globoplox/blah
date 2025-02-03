const webpack = require('webpack');
const path = require('path');
const HtmlWebpackPlugin = require("html-webpack-plugin")

module.exports = {
  mode: process.env['ENV'] || 'production',
  devtool: (process.env['ENV'] == 'development' ?  'source-map' : undefined),
  entry: './src/main.tsx',

  resolve: {
    extensions: ['.js', '.jsx', '.tsx', '.ts'],
    modules: ['node_modules'],
  },
  
  output: {
    filename: 'blah-app-webapp.js',
    path: path.resolve(__dirname, 'dist'),
    publicPath: '/'
  },

  module: {
    rules: [
      {
        test: /\.woff($|\?)|\.woff2($|\?)|\.ttf($|\?)|\.eot($|\?)|\.svg($|\?)/i,
        type: 'asset/resource',
        generator: {
            filename: 'fonts/[name][ext][query]'
        }
      },

      {
        test: /\.ts(x)?$/,
        loader: 'ts-loader',
      },
      {
        test: /\.sass|.scss|.css$/i,
        use: [
          "style-loader",
          "css-loader",
          "sass-loader",
        ]
      }
    ]
  },

  devServer: {
    hot: true,
    port: 8080,
    historyApiFallback: true

},

  plugins: [
    
    new webpack.DefinePlugin({
      "process.env.API_SERVER_URI": JSON.stringify("http://localhost:3000")
    }),

    new HtmlWebpackPlugin({
      template: "./src/index.html"
    })
  ],  
};
