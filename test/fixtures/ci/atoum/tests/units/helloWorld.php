<?php

namespace
{
	class Greetings
	{
		public function helloWorld() {
			return "Hello World";
		}
	}
}

namespace tests\units
{
	use atoum\atoum;
	
	class Greetings extends atoum\test
	{
		public function testHelloWorld()
		{
			$this
				->if($this->newTestedInstance)
				->then
					->string($this->testedInstance->helloWorld())
						->isEqualTo("Hello World");
		}
	}
}
