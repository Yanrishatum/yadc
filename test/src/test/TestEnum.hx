package test;

/**
 * @author Yanrishatum
 */

@:include
enum TestEnum 
{
  TypicalValue;
  ParametrizedValue(t:Dynamic);
  ParametrizedValue2(t:Dynamic, b:Dynamic);
}