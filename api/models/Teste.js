/**
 * Teste.js
 *
 * @description :: TODO: You might write a short summary of how this model works and what it represents here.
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {

//connection: 'db_server',

  attributes: {
    tableName: 'teste',
    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },
    name: {
      columnName: 'name',
      type: 'string',
      required: true

    },

    description: {
      columnName: 'descricao',
      type: 'string'
    }

  }
};

