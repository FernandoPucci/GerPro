/**
 * Auditions.js
 *
 * @description :: Representative model from Auditions table
 * @docs        :: http://sailsjs.org/documentation/concepts/models-and-orm/models
 * 
 * 
 */

module.exports = {
  //connection: 'db_server',
  //configurations to disale UpdateAt and CreatedAt Waterline Columns
  autoCreatedAt: false,
  autoUpdatedAt: false,
  attributes: {

    id: {
      type: 'integer',
      autoIncrement: true,
      unique: true,
      primaryKey: true
    },

    table_name: {
      type: 'string',
      required: true
    },
    operation: {
      type: 'string',
      columnName: 'operation',
      required: true
    },
    primary_key: {
      type: 'string',
      required: true
    },
    old_values: {
      type: 'string',
    },
    created_at: {
      type: 'datetime'
    },
    updated_by_user: {
      type: 'integer',
      columnName: 'updated_by_user_id',
      required: true
    }
  }
};

