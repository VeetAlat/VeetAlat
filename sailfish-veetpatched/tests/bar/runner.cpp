// qmltestrunner, which the SDK target lacks: Qt's QuickTest library is
// there, without its headers, so its entry point is declared here.
int quick_test_main(int argc, char **argv, const char *name, const char *sourceDir);

int main(int argc, char **argv)
{
    return quick_test_main(argc, argv, "barlayout", ".");
}
