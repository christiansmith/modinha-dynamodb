/**
 * Module dependencies
 */


/**
 * Mixin
 */

function DynamoDBDocument () {}


/**
 * Get
 */

DynamoDBDocument.get = function (ids, options, callback) {
  var Model      = this
    , collection = Model.collection
    , uniqueId   = Model.uniqueId
    , db         = Model.__db
    , key        = {}
    ;

  // optional options argument
  if (!callback) {
    callback = options;
    options = {};
  }

  // return an object instead of an array
  // if the first argument is a string
  if (typeof ids === 'string') {
    options.first = true;
    ids = [ids];
  }

  // don't call batchGetItem with undefined ids
  if (!ids) {
    return callback(null, null);
  }

  // don't call batchGetItem with an empty array
  if (Array.isArray(ids) && ids.length === 0) {
    return callback(null, [])
  }

  keys = ids.map(function (id) {
    var key = {};
    key[uniqueId] = id;
    return key;
  });

  var items = {};
  items[collection] = {
    Keys: keys
  };

  db.batchGetItem({
    RequestItems: items
  }, function (err, data) {
    if (err) { return callback(err); }
    var docs = data && data.Responses && data.Responses[collection];
    if (!docs) { return callback(null, null); }
    callback(null, Model.initialize(docs, options));
  });
};


/**
 * Insert
 */

DynamoDBDocument.insert = function (data, options, callback) {
  var Model       = this
    , collection  = Model.collection
    , instance    = Model.initialize(data, { private: true })
    , validation  = instance.validate()
    , db          = Model.__db
    ;

  // optional options
  if (!callback) {
    callback = options;
    options  = {};
  }

  // handle invalid data
  if (!validation.valid) { return callback(validation); }

  db.putItem({
    TableName: collection,
    Item:      instance
  }, function (err, result) {
    if (err) { return callback(err); }
    callback(null, Model.initialize(instance, options));
  });
};


/**
 * Replace
 */

DynamoDBDocument.replace = function (id, data, options, callback) {
  var Model       = this
    , collection  = Model.collection
    , instance    = Model.initialize(data, { private: true })
    , validation  = instance.validate()
    , db          = Model.__db
    ;

  // optional options
  if (!callback) {
    callback = options;
    options  = {};
  }

  // handle invalid data
  if (!validation.valid) { return callback(validation); }

  db.putItem({
    TableName: collection,
    Item:      instance
  }, function (err, result) {
    if (err) { return callback(err); }
    callback(null, Model.initialize(instance, options));
  });
};


/**
 * Patch
 */

DynamoDBDocument.patch = function (id, data, options, callback) {
  var Model      = this
    , collection = Model.collection
    , uniqueId   = Model.uniqueId
    , db         = Model.__db
    ;

  // optional options
  if (!callback) {
    callback = options;
    options = {};
  }

  // get the existing data
  Model.get(id, { private:true }, function (err, instance) {
    if (err) { return callback(err); }

    // not found?
    if (!instance) { return callback(null, null); }

    // copy the original (for reindexing)
    var original = Model.initialize(instance, { private: true });

    // merge the new values into the instance
    // without generating default values
    instance.merge(data, { defaults: false });

    // update the timestamp
    instance.modified = Model.defaults.timestamp()

    // validate the mutated instance
    var validation = instance.validate();
    if (!validation.valid) { return callback(validation); }

    Model.replace(id, data, options, function (err, data) {
      if (err) { return callback(err); }
      callback(null, Model.initialize(instance, options));
    });
  });
};


/**
 * Delete
 */

DynamoDBDocument.delete = function (id, callback) {
  var Model      = this
    , collection = Model.collection
    , uniqueId   = Model.uniqueId
    , db         = Model.__db
    , key        = {}
    ;

  // Get the object so that it can be deindexed
  Model.get(id, { private: true }, function (err, result) {
    if (err) { return callback(err); }

    // not found
    if (!result) { return callback(null, null); }

    key[uniqueId] = id;
    db.deleteItem({
      TableName: collection,
      Key:       key
    }, function (err, result) {
      if (err) { return callback(err); }
      callback(null, true);
    });
  });
};


/**
 * Post Extend
 */

DynamoDBDocument.__postExtend = function () {
  var Model      = this
    , collection = Model.collection
    , uniqueId   = Model.uniqueId
    , schema     = Model.schema
    ;

  // ensure a unique identifier is defined
  if (!schema[uniqueId]) {
    schema[uniqueId] = {
      type:     'string',
      required:  true,
      default:   Model.defaults.uuid,
      format:   'uuid'
    };
  }

  // add timestamps to schema
  var timestamp = { type: 'number', order: true, default: Model.defaults.timestamp }
  if (!schema.created)  { schema.created  = timestamp; }
  if (!schema.modified) { schema.modified = timestamp; }
};


/**
 * Exports
 */

module.exports = DynamoDBDocument;
