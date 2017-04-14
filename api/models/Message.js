/**
 * Message.js
 *
 * @description :: TODO: You might write a short summary of how this model works and what it represents here.
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

 //connection: 'db_server',

  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },

    to: {
      columnName: 'to',
      type: 'string',
      required: true

    },

    subject: {
      columnName: 'subject',
      type: 'string',
      required: true

    },
    message: {
      columnName: 'message',
      type: 'string',
      required: true

    }
  }
};

