@IsTest
private class DemoTowAdityaTest {

    @IsTest
    static void testDemoTowAdityaConstructor() {
        Test.startTest();
        DemoTowAditya obj = new DemoTowAditya();
        Test.stopTest();

        System.assertNotEquals(null, obj);
    }
}