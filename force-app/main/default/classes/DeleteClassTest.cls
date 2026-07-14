@IsTest
private class DeleteClassTest {

    @IsTest
    static void testConstructor() {

        Test.startTest();

        DeleteClass obj = new DeleteClass();

        Test.stopTest();

        System.assertNotEquals(null, obj);
    }
}