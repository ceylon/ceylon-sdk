import ceylon.file {
    File,
    Path,
    parsePath
}
import ceylon.transaction.tm {
    bindDataSources,
    transactionManager,
    recoveryScan
}

import java.lang {
    System {
        setProperty,
        getProperty
    }
}

shared interface RecoveryManager {
    shared formal void start(String? dataSourceConfigPropertyFile = null);
    shared formal void scan();
    shared formal void parseCommandInput();
}

shared class RecoveryManagerImpl() satisfies RecoveryManager {

    void init() {
        String userDir = getProperty("user.dir", "") + "/tmp";
        setProperty("com.arjuna.ats.arjuna.objectstore.objectStoreDir", userDir);
        setProperty("com.arjuna.ats.arjuna.common.ObjectStoreEnvironmentBean.objectStoreDir", userDir);

        transactionManager.start(true);
    }

    shared actual void start(String? dataSourceConfigPropertyFile) {
        init();
        bindDSProperties(dataSourceConfigPropertyFile);
    }

    shared actual void scan() {
        recoveryScan();
    }

    shared actual void parseCommandInput() {
        process.write("> ");
        while (exists line = process.readLine()) {
            if (line == "quit") {
                transactionManager.stop();
                break;
            } else if (line == "scan") {
                print("scanning");
                scan();
                print("finished scan");
            //} else if (line.contains("dbc.properties=")) {
                //String? propFile = line.split((Character c) => c == '=').rest.first;
                //bindDSProperties(propFile);
            } else {
                print("Valid command options are:");
                print("\tquit - shutdown the recovery manager and exit");
                print("\tscan - perform a synchronous recovery scan (ie find and recover pending transaction branches)");
                //print("\tdbc.properties=<datasource properties file location>");
            }

            process.write("> ");
        }
    }

    void bindDSProperties(String? dataSourceConfigPropertyFile) {
        if (exists dataSourceConfigPropertyFile) {
            String propFile = dataSourceConfigPropertyFile.trimmed;

            Path path = parsePath(propFile);

            if (is File f = path.resource) {
                print("configuring datasources via properties file ``propFile``");
                bindDataSources(propFile);
            } else {
                print("warning: no datasources configured - property file ``propFile`` does not exist");
            }
         } else {
             print("warning: no datasources configured - missing property file");
         }
    }
}

"Command line run method of the module.
 ceylon run --rep=modules --run=ceylon.transaction.rm.run
 --define=dbc.properties=<datasource config file> --define=interactive=true
 ceylon.transaction"
by("Mike Musgrove")
shared void run() {
    for (arg in process.arguments) {
        if (arg.contains == "help" || arg.contains == "?") {
            print("Start a transaction recovery manager.");
            print("For interactive mode run with --define=interactive=true");
            print("For recovery to operate correctly you must define which datasources are needed");
            print("by either putting a file called dbc.properties on the class path or by defining an");
            print("alternative file location using --define=dbc.properties=<file name>");
            print("The format for defining datasources is java properties file format");

            return;
        }
    }

    RecoveryManagerImpl rm = RecoveryManagerImpl();
    String? dataSourceConfigPropertyFile = process.propertyValue("dbc.properties");
    String? interactive = process.propertyValue("interactive");

    rm.start(dataSourceConfigPropertyFile);
    print("Recovery Manager running ...");

    if (exists interactive) {
        rm.parseCommandInput();
    } else {
        print("daemon mode");
    }
}
