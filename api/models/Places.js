/**
 * Places.js
 *
 * @description :: TODO: You might write a short summary of how this model works and what it represents here.
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 */

module.exports = {
  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  tableName: 'places',
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },
    company_id: {
      type: 'integer',
      required: true
    },
    name: {
      type: 'string',
      required: true
    },
    description: {
      type: 'text'      
    },
    created_at: {
      type: 'datetime'
    },
    updated_at: {
      type: 'datetime'
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id',
      required: true
    }

  }
};

