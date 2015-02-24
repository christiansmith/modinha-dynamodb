# Test dependencies
cwd       = process.cwd()
path      = require 'path'
Faker     = require 'Faker'
chai      = require 'chai'
sinon     = require 'sinon'
sinonChai = require 'sinon-chai'
expect    = chai.expect




# Configure Chai and Sinon
chai.use sinonChai
chai.should()




# Code under test
Modinha          = require 'modinha'
DynamoDBDocument = require path.join(cwd, 'lib/DynamoDBDocument')




# AWS SDK
AWS = require 'aws-sdk'
db  = new AWS.DynamoDB apiVersion: 'latest'




describe 'DynamoDBDocument', ->


  {Document,data,documents,jsonDocuments,document} = {}
  {err,instance,instances,update,deleted,original,ids} = {}


  before ->
    schema =
      description: { type: 'string', required:  true }
      unique:      { type: 'string', unique:    true }
      undefUnique: { type: 'string', unique:    true }
      secret:      { type: 'string', private:   true }
      secondary:   { type: 'string', secondary: true }
      reference:   { type: 'string', reference: { collection: 'references' } }


    Document = Modinha.define 'documents', schema
    Document.extend DynamoDBDocument


    Document.__AWS = AWS
    Document.__db  = db

    # Mock data
    data = []

    for i in [0..9]
      data.push
        description: Faker.Lorem.words(5).join(' ')
        unique: Faker.random.number(1000).toString()
        secondary: Faker.random.number(1000).toString()
        reference: Faker.random.number(1000).toString()
        indexed: Faker.random.number(1000).toString()
        secret: 'nobody knows'

    documents = Document.initialize(data, { private: true })
    jsonDocuments = documents.map (d) ->
      Document.serialize(d)
    ids = documents.map (d) ->
      d._id




  describe 'schema', ->

    it 'should have unique identifier', ->
      Document.schema[Document.uniqueId].should.be.an.object

    it 'should have "created" timestamp', ->
      Document.schema.created.default.should.equal Modinha.defaults.timestamp

    it 'should have "modified" timestamp', ->
      Document.schema.modified.default.should.equal Modinha.defaults.timestamp





  describe 'get', ->

    describe 'by string', ->

      before (done) ->
        document = documents[0]
        json = jsonDocuments[0]
        response =
          Responses:
            documents: [document]

        sinon.stub(db, 'batchGetItem').callsArgWith 1, null, response
        Document.get documents[0]._id, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.batchGetItem.restore()

      it 'should provide null error', ->
        expect(err).to.be.null

      it 'should provide an instance', ->
        expect(instance).to.be.instanceof Document

      it 'should correctly destructure the response', ->
        instance.description.should.equal document.description

      it 'should not initialize private properties', ->
        expect(instance.secret).to.be.undefined


    describe 'by string not found', ->

      before (done) ->
        sinon.stub(db, 'batchGetItem').callsArgWith 1, null, {}
        Document.get 'unknown', (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.batchGetItem.restore()

      it 'should provide null error', ->
        expect(err).to.be.null

      it 'should provide a null result', ->
        expect(instance).to.be.null


    describe 'by array', ->

      before (done) ->
        response = { Responses: { documents: jsonDocuments } }
        sinon.stub(db, 'batchGetItem').callsArgWith 1, null, response
        Document.get ids, (error, results) ->
          err = error
          instances = results
          done()

      after ->
        db.batchGetItem.restore()

      it 'should provide null error', ->
        expect(err).to.be.null

      it 'should provide a list of instances', ->
        instances.length.should.equal 10
        instances.forEach (instance) ->
          expect(instance).to.be.instanceof Document

      it 'should not initialize private properties', ->
        instances.forEach (instance) ->
          expect(instance.secret).to.be.undefined


    describe 'with empty array', ->

      before (done) ->
        Document.get [], (error, results) ->
          err = error
          instances = results
          done()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide an empty array', ->
        Array.isArray(instances).should.be.true
        instances.length.should.equal 0


    describe 'with selection', ->

      before (done) ->
        response = { Responses: { documents: jsonDocuments } }
        sinon.stub(db, 'batchGetItem').callsArgWith 1, null, response
        Document.get ids, { select: [ 'description', 'secret' ] }, (error, results) ->
          err = error
          instances = results
          done()

      after ->
        db.batchGetItem.restore()

      it 'should provide null error', ->
        expect(err).to.be.null

      it 'should provide a list of instances', ->
        instances.length.should.equal 10
        instances.forEach (instance) ->
          expect(instance).to.be.instanceof Document

      it 'should only initialize selected properties', ->
        instances.forEach (instance) ->
          expect(instance._id).to.be.undefined
          instance.description.should.be.a.string

      it 'should initialize private properties if selected', ->
        instances.forEach (instance) ->
          instance.secret.should.be.a.string


    describe 'with private option', ->

      before (done) ->
        document = documents[0]
        json = jsonDocuments[0]
        response =
          Responses:
            documents: [document]

        sinon.stub(db, 'batchGetItem').callsArgWith 1, null, response
        Document.get documents[0]._id, { private: true }, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.batchGetItem.restore()

      it 'should provide null error', ->
        expect(err).to.be.null

      it 'should provide an instance', ->
        expect(instance).to.be.instanceof Document

      it 'should initialize private properties', ->
        expect(instance.secret).to.equal 'nobody knows'





  describe 'insert', ->

    describe 'with valid data', ->

      beforeEach (done) ->
        sinon.stub(db, 'putItem').callsArgWith 1, null, {}

        Document.insert data[0], (error, result) ->
          err = error
          instance = result
          done()

      afterEach ->
        db.putItem.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the inserted instance', ->
        expect(instance).to.be.instanceof Document

      it 'should not provide private properties', ->
        expect(instance.secret).to.be.undefined

      #it 'should store the serialized instance by unique id', ->
      #  multi.hset.should.have.been.calledWith 'documents', instance._id, sinon.match('"secret":"nobody knows"')

      #it 'should index the instance', ->
      #  Document.index.should.have.been.calledWith sinon.match.object, sinon.match(instance)


    describe 'with invalid data', ->

      before (done) ->
        sinon.stub(db, 'putItem').callsArgWith 1, null, {}
        Document.insert {}, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.putItem.restore()

      it 'should provide a validation error', ->
        err.should.be.instanceof Modinha.ValidationError

      it 'should not provide an instance', ->
        expect(instance).to.be.undefined

      it 'should not store the data', ->
        db.putItem.should.not.have.been.called

    #  it 'should not index the data', ->
    #    Document.index.should.not.have.been.called


    describe 'with private values option', ->

      beforeEach (done) ->
        sinon.stub(db, 'putItem').callsArgWith 1, null, {}
        Document.insert data[0], { private: true }, (error, result) ->
          err = error
          instance = result
          done()

      afterEach ->
        db.putItem.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the inserted instance', ->
        expect(instance).to.be.instanceof Document

      it 'should provide private properties', ->
        expect(instance.secret).to.equal 'nobody knows'


    describe 'with duplicate unique values', ->

      beforeEach (done) ->
        #sinon.stub(Document, 'getByUnique')
        #  .callsArgWith 1, null, documents[0]

        #Document.insert data[0], (error, result) ->
        #  err = error
        #  instance = result
        #  done()

      afterEach ->
        #Document.getByUnique.restore()

      it 'should provide a unique value error'
        #expect(err).to.be.instanceof Document.UniqueValueError

      it 'should not provide an instance'
        #expect(instance).to.be.undefined




  describe 'replace', ->

    describe 'with valid data', ->

      before (done) ->
        document = documents[0]
        update =
          _id: document._id
          description: 'updated'

        sinon.stub(db, 'putItem').callsArgWith 1, null, {}
        Document.replace document._id, update, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.putItem.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the replaced instance', ->
        expect(instance).to.be.instanceof Document

      it 'should not provide private properties', ->
        expect(instance.secret).to.be.undefined

      it 'should replace the existing instance', ->
        expect(instance.description).to.equal 'updated'
        expect(instance.secret).to.be.undefined
        expect(instance.secondary).to.be.undefined

      #it 'should reindex the instance', ->
      #  Document.reindex.should.have.been.calledWith sinon.match.object, sinon.match(update), documents[0]


    describe 'with unknown document', ->

      before (done) ->
        Document.replace 'unknown', {}, (error, result) ->
          err = error
          instance = result
          done()

      after ->

      it 'should provide an null error'
        #expect(err).to.be.null

      it 'should not provide an instance'
        #expect(instance).to.be.null


    describe 'with invalid data', ->

      before (done) ->
        doc = documents[0]

        Document.replace doc._id, { description: -1 }, (error, result) ->
          err = error
          instance = result
          done()

      it 'should provide a validation error', ->
        expect(err).to.be.instanceof Modinha.ValidationError

      it 'should not provide an instance', ->
        expect(instance).to.be.undefined


    describe 'with private values option', ->

      before (done) ->
        doc = documents[0]
        json = jsonDocuments[0]
        update =
          _id: doc._id
          description: 'updated'
          secret: 'still a secret'

        sinon.stub(db, 'putItem').callsArgWith 1, null, {}
        Document.replace doc._id, update, { private: true }, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        db.putItem.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the replaced instance', ->
        expect(instance).to.be.instanceof Document

      it 'should provide private properties', ->
        expect(instance.secret).to.equal 'still a secret'


    describe 'with duplicate unique values', ->

      beforeEach (done) ->
    #    doc1 = documents[0]
    #    doc2 = Document.initialize(documents[1]) # copy this doc
    #    doc2.unique = doc1.unique
    #    Document.replace doc2._id, doc2, (error, result) ->
    #      err = error
    #      instance = result
          done()

      afterEach ->

      it 'should provide a unique value error'
        #expect(err).to.be.instanceof Document.UniqueValueError

      it 'should not provide an instance'
        #expect(instance).to.be.undefined




  describe 'patch', ->

    describe 'with valid data', ->

      before (done) ->
        doc = documents[0]
        json = jsonDocuments[0]
        update =
          _id: doc._id
          description: 'updated'

        sinon.stub(Document, 'get').callsArgWith 2, null, doc
        sinon.stub(Document, 'replace').callsArgWith 3, null, {}
        Document.patch doc._id, update, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        Document.get.restore()
        Document.replace.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the patched instance', ->
        expect(instance).to.be.instanceof Document

      it 'should not provide private properties', ->
        expect(instance.secret).to.be.undefined

      it 'should not generate default values', ->
        instance._id.should.equal documents[0]._id
        instance.created.should.equal documents[0].created

      it 'should update the "modified" timestamp', ->
        instance.modified.should.not.equal documents[0].created

      #it 'should overwrite the stored data', ->
      #  multi.hset.should.have.been.calledWith 'documents', instance._id, sinon.match('"description":"updated"')

      #it 'should reindex the instance', ->
      #  Document.reindex.should.have.been.calledWith sinon.match.object, sinon.match(update), sinon.match(documents[0])


    describe 'with unknown document', ->

      before (done) ->
        sinon.stub(Document, 'get').callsArgWith(2, null, null)
        Document.patch 'unknown', {}, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        Document.get.restore()

      it 'should provide an null error', ->
        expect(err).to.be.null

      it 'should not provide an instance', ->
        expect(instance).to.be.null


    describe 'with invalid data', ->

      before (done) ->
        doc = documents[0]
        json = jsonDocuments[0]

        sinon.stub(Document, 'get').callsArgWith(2, null, doc)
        Document.patch doc._id, { description: -1 }, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        Document.get.restore()

      it 'should provide a validation error', ->
        expect(err).to.be.instanceof Modinha.ValidationError

      it 'should not provide an instance', ->
        expect(instance).to.be.undefined


    describe 'with private values option', ->

      before (done) ->
        doc = documents[0]
        json = jsonDocuments[0]

        sinon.stub(Document, 'get').callsArgWith(2, null, doc)
        sinon.stub(Document, 'replace').callsArgWith 3, null, {}
        update =
          _id: doc._id
          description: 'updated'


        Document.patch doc._id, update, { private:true }, (error, result) ->
          err = error
          instance = result
          done()

      after ->
        Document.get.restore()
        Document.replace.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide the replaced instance', ->
        expect(instance).to.be.instanceof Document

      it 'should provide private properties', ->
        expect(instance.secret).to.be.a.string


    describe 'with duplicate unique values', ->

      beforeEach (done) ->
        doc1 = documents[0]
        doc2 = documents[1]
        update = Document.initialize(documents[1]) # copy this doc
        update.unique = doc1.unique

        Document.patch doc2._id, update, (error, result) ->
          err = error
          instance = result
          done()

      afterEach ->

      it 'should provide a unique value error'
        #expect(err).to.be.instanceof Document.UniqueValueError

      it 'should not provide an instance'
        #expect(instance).to.be.undefined




  describe 'delete', ->

    describe 'by string', ->

      before (done) ->
        instance = documents[0]
        sinon.stub(Document, 'get').callsArgWith(2, null, instance)
        sinon.stub(db, 'deleteItem').callsArgWith(1, null, {})
        Document.delete instance._id, (error, result) ->
          err = error
          deleted = result
          done()

      after ->
        Document.get.restore()

      it 'should provide a null error', ->
        expect(err).to.be.null

      it 'should provide confirmation', ->
        deleted.should.be.true

      it 'should remove the stored instance'


    describe 'with unknown document', ->

      before (done) ->
        sinon.stub(Document, 'get').callsArgWith(2, null, null)
        Document.delete 'unknown', (error, result) ->
          err = error
          instance = result
          done()

      after ->
        Document.get.restore()

      it 'should provide an null error', ->
        expect(err).to.be.null

      it 'should not provide an instance', ->
        expect(instance).to.be.null





