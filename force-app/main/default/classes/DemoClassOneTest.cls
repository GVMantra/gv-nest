@isTest
private class DemoClassOneTest {

    @isTest
    static void testDemoClassOne() {
        DemoClassOne obj = new DemoClassOne();
        System.assertNotEquals(null, obj);
    }
}