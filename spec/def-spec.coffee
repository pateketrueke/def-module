def = require('..')

describe 'def()', ->
  it 'should be a function', ->
    expect(typeof def).toEqual 'function'

  describe 'self', ->
    it 'should return a new scope without arguments', ->
      a = def()
      b = def()

      expect(a).not.toBe b
      expect(-> a('x')).not.toThrow()
      expect(-> b('y')).not.toThrow()
      expect(a.x).not.toBeUndefined()
      expect(b.x).toBeUndefined()
      expect(a.y).toBeUndefined()
      expect(b.y).not.toBeUndefined()

  describe 'errors', ->
    it 'should fail on invalid definitions', ->
      expect(-> def('no_redefine', @)({
        new: ->
          42
      })).toThrow()

      expect(-> def('no_objects').use(-1).new()).toThrow()

  describe 'modules', ->
    it 'can define local modules', ->
      def 'local_module', @
      expect(@local_module).not.toBeUndefined()
      expect(typeof local_module).toEqual 'undefined'

    it 'can define global modules', ->
      def 'global_module'
      expect(global_module).not.toBeUndefined()

    it 'can namespace any sub.modules', ->
      def 'my.submodule.is_global'
      expect(typeof my.submodule.is_global).toEqual 'function'

    it 'should return its own definition', ->
      Alias = def('MyClass', @)

      expect(typeof MyClass).toEqual 'undefined'
      expect(@MyClass).toBe Alias

    it 'should allow you to enhance definitions', ->
      def('A', @)({ a: 'b' })
      expect(@A.a).toEqual 'b'
      expect(@A.x).toBeUndefined()

      def('A', @)({ x: 'y' })
      expect(@A.x).toEqual 'y'

      # scoped syntax
      @A({ foo: 'bar' })
      expect(@A.foo).toEqual 'bar'

    if parseFloat(process.version.substr(1)) > 1
      it 'should provide the registered definition name', ->
        def('MyClass', @)
        expect(@MyClass.name).toEqual 'MyClass'
        expect(@MyClass.new().constructor.name).toEqual 'MyClass'

        def('ParentClass', @)({
          constructor: ->
            @className = @constructor.name
        })
        def('ChildClass', @).use(@ParentClass)

        expect(@ParentClass.new().className).toEqual 'ParentClass'
        expect(@ChildClass.new().className).toEqual 'ChildClass'

  describe 'methods', ->
    describe 'new()', ->
      beforeEach ->
        def('MyClass', @)({
          staticProperty: 'foo'
          prototype:
            instanceProperty: 'bar'
        })

      it 'should support static properties', ->
        expect(@MyClass.staticProperty).toEqual 'foo'

      it 'can create classes from defined modules', ->
        expect(typeof @MyClass.new).toEqual 'function'
        expect(@MyClass.new().instanceProperty).toEqual 'bar'

  describe 'inheritance', ->
    it 'can define static properties', ->
      def('Container', @)({ test: 'value' })
      expect(@Container.test).toEqual 'value'

    it 'can inherit static properties', ->
      def('MainClass', @)({ foo: 'bar' })
      def('SubClass', @)({ baz: 'buzz' })
      def([@MainClass, @SubClass], 'ThirdClass', @)({ baz: 'bazzinga!' });

      expect(@SubClass.baz).toEqual 'buzz'
      expect(@ThirdClass.foo).toEqual 'bar'
      expect(@ThirdClass.baz).toEqual 'bazzinga!'

    it 'will use composition for the initial definition', ->
      def('Parent', @)({ prototype: { foo: 'bar' } })
      def('Other', @)({ prototype: { extra: (str) -> '(' + str() + ')' } })
      def([@Parent, @Other], 'Children', @)({ prototype: { baz: 'buzz', test: -> @foo + '!!' } })

      c = @Children.new()
      expect(c.foo).toEqual 'bar'
      expect(c.baz).toEqual 'buzz'
      expect(c.extra(c.test)).toEqual '(bar!!)'

    it 'will extends existing definitions on the next calls', ->
      def('PluginBase', @)({ prototype: { type: 'plugin' } })
      def(@PluginBase, 'MyPlugin', @)

      expect(@MyPlugin.new().type).toEqual 'plugin'
      expect(@MyPlugin.new().fun).toBeUndefined()

      def('PluginMixin', @)({ prototype: { fun: -> 'OSOM' }  })
      def(@PluginMixin, @PluginBase, @)

      expect(@MyPlugin.new().type).toEqual 'plugin'
      expect(@MyPlugin.new().fun()).toEqual 'OSOM'

    it 'should support multiple constructors through definitions', ->
      count = 0

      def('HooksSupport', @)({
        constructor: ->
          count++
          @prop = Math.random()
        prototype:
          hooks: true
      })

      def(@HooksSupport, 'ExtraSupport', @)({
        constructor: ->
          count++
      })

      def(@ExtraSupport, 'FancyClass', @)({
        constructor: (@prefix) ->
          @prefix += '2' if @hooks
        prototype:
          test: ->
            @prefix + '3'
      })

      expect(@FancyClass.new().prop).not.toEqual @FancyClass.new().prop
      expect(@FancyClass.new('1').test()).toEqual '123'
      expect(count).toEqual 3 * 2

    it 'should be able to create objects from factories or through the new operator', ->
      def('BaseClass', @)({ prototype: { foo: 'bar' } })
      def(@BaseClass, 'ChildClass', @)({ prototype: { baz: 'buzz' } })
      @ChildClass.use({ prototype: { candy: 'does nothing' } })

      a = @ChildClass.new()
      b = new @ChildClass()

      expect(a.foo).toEqual 'bar'
      expect(a.baz).toEqual 'buzz'
      expect(a.candy).toEqual 'does nothing'

      expect(b.foo).toEqual 'bar'
      expect(b.baz).toEqual 'buzz'
      expect(b.candy).toEqual 'does nothing'
