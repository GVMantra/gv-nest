@IsTest
private class DemoClassOneTest {

    @IsTest
    static void testDemoClassOneConstructor() {
        Test.startTest();
        DemoClassOne obj = new DemoClassOne();
        Test.stopTest();

        System.assertNotEquals(null, obj);
    }
}