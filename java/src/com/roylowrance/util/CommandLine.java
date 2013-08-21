package com.roylowrance.util;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

// helpers for reading the command line
public class CommandLine {
    private String[] args;

    public class Exception extends RuntimeException {
        public Exception(String msg) {
            super(msg);
        }
    }

    public CommandLine(String[] args) {
        this.args = args;
    }

    // return value of double parameter
    // throw if not present or present but doesn't represent a double
    public String optionIsDate(String option) {
        String optionString = optionValue(option);
        if (Represents.date(optionString))
            return optionString;
        throw new IllegalArgumentException("option " + option + " does not represent a date value");
    }

    // return value of double parameter
    // throw if not present or present but doesn't represent a double
    public double optionIsDouble(String option) {
        String optionString = optionValue(option);
        if (Represents.double_(optionString))
            return Double.valueOf(optionString);
        throw new IllegalArgumentException("option " + option + " does not represent a double value");
    }

    // return value of optional parameter
    // throw if not present or not in a specified list of allowed values
    public String optionIsOneOf(String option, String... allowedValues) {
        if (!isPresent(option))
            throw new IllegalArgumentException("command line is missing parameter " + option);
        String result = getOptionValue(option);
        String allAllowedValues = "";
        for (String allowedValue : allowedValues) {
            allAllowedValues += allowedValue + " ";
            if (result.equals(allowedValue))
                return result;
        }
        throw new IllegalArgumentException("option " + option + " not one of " + allAllowedValues);
    }

    // return value of the option as a string, which must be present
    // throw if its not present
    public String optionValue(String option) {
        if (isPresent(option))
            return getOptionValue(option);
        else
            throw new IllegalArgumentException("command line is missing parameter " + option);
    }

    // return value of option as an integer
    // throw if not present or not an integer
    public int optionValueInteger(String optionName) {
        final String value = optionValue(optionName);
        if (Represents.int_(value))
            return Integer.valueOf(value);
        throw new IllegalArgumentException("must be an integer; option value = " + value);
    }

    /**
     * get the value of the option. Throw Exception if its not found
     * 
     * @param optionName
     * @return
     * @throws Exception
     *             if the option is not in the command line
     */
    public String getOptionValue(String optionName) {
        Log log = new Log("CommandLine.getOptionValue", false);
        for (String arg : args) {
            log.println("arg:<" + arg + "> optionName:<" + optionName + ">");
            if (!arg.startsWith(optionName))
                continue;
            final int equalSignIndex = arg.indexOf("=");
            if (equalSignIndex == -1)
                throw new Exception("arg " + arg + " is not followed by =optionValue");
            log.println("arg:<" + arg + "> equalSignIndex:" + equalSignIndex);
            return arg.substring(equalSignIndex + 1);
        }
        throw new Exception("optionName " + optionName + " is not in command line=" + asString(args));
    }

    private String asString(String[] args) {
        String result = "";
        for (String arg : args)
            result += arg + " ";
        return result;
    }

    // --optionName ; return whether present
    public boolean isPresent(String optionName) {
        for (String arg : args) {
            if (arg.startsWith(optionName))
                return true;
        }
        return false;
    }

    // --optionName=(v1,v2,...); return list of values that were separated by commas
    public String[] getOptionValueList(String optionName) {
        Log log = new Log("CommandLine.getOptionValueList", false);
        for (String arg : args) {
            log.println("arg:" + arg);
            if (!arg.startsWith(optionName))
                continue;
            final String regex = ",";
            final int limit = -1; // no limit
            final int firstParenIndex = arg.indexOf("(");
            final int lastParenIndex = arg.lastIndexOf(")");
            if (firstParenIndex == -1 || lastParenIndex == -1)
                throw new Exception("values in " + arg + " not surrounded by parens, as in --opt=(v1,v2)");
            if (firstParenIndex + 1 == lastParenIndex) {
                // split doesn't handle this case well
                // return an empty array of zero length
                return new String[0];
            }
            final String sub = arg.substring(firstParenIndex + 1, lastParenIndex);
            log.println("sub:" + sub);
            return sub.split(regex, limit);
        }
        throw new Exception("optionName " + optionName + " is not in command line " + args);
    }

    // value ... ; return list of non-option values
    public String[] getNonOptionList(String optionPrefixes) {
        Log log = new Log("CommandLine.getNonOptionList", false);
        List<String> resultList = new LinkedList<String>();
        for (String arg : args) {
            for (int i = 0; i < optionPrefixes.length(); i++) {
                log.println("i:" + i);
                final String optionPrefix = optionPrefixes.substring(i, i + 1);
                log.println("option prefix String:<" + optionPrefix + ">");
                if (arg.startsWith(optionPrefix))
                    ; // arg starts with a character used to designate an option
                else
                    resultList.add(arg); // arg isn't an option, so save it
            }
        }
        // convert the list to an array of String
        String[] result = new String[resultList.size()];
        int i = 0;
        for (String arg : resultList) {
            result[i] = arg;
            i++;
        }
        return result;
    }

    // return Tuple2<String,String> containing two parameters in form [VALUE1,VALUE2] or similar
    /**
     * Return tuple of strings containing values of parameter --PARM=[BLAH1,BLAH2] or similar form
     * 
     * @param parameterName
     *            name of the parameter; in example: --PARM
     * @param leftBracket
     *            String starting the sequence; in example: [
     * @param comma
     *            String separating items; in example: ,
     * @param rightBracket
     *            String ending sequence; in example: ]
     * @return Tuple2<String,String> containing items; in example: BLAH1 and BLAH2
     * @throws Exception
     *             if the parameter --PARM is not in the command line
     */
    public Tuple2<String, String> extractSequence2(String parameterName, String leftBracket, String comma, String rightBracket) {
        Log log = new Log("CommandLine.extractSequence2", false);
        String value = getOptionValue(parameterName);
        int beginIndex = value.indexOf(leftBracket);
        int commaIndex = value.indexOf(comma);
        int endIndex = value.indexOf(rightBracket);
        log.println("beginIndex:" + beginIndex + " commaIndex:" + commaIndex + " endIndex:" + endIndex);
        log.println("parameterName:" + parameterName);
        log.println("value:" + value);
        log.println("leftBracket:<" + leftBracket + "> comma;<" + comma + "> rightBracket:<" + rightBracket + ">");
        return new Tuple2<String, String>(value.substring(beginIndex + 1, commaIndex), value.substring(commaIndex + 1, endIndex));
    }

    // return array of String containing value of parameter --PARM=[BLAH1,BLAH2,...,BLAHn]
    public List<String> extractSequence(String parameterName, String leftBracket, String comma, String rightBracket) {
        Log log = new Log("CommandLine.extractSequence", true);
        String value = getOptionValue(parameterName);
        List<String> result = new ArrayList<String>();

        int lb = value.indexOf(leftBracket);
        if (lb == -1)
            throw new RuntimeException("command missing left bracket");

        int rb = value.indexOf(rightBracket);
        if (rb == -1)
            throw new RuntimeException("command missing right bracket");

        int start = lb + 1;
        while (true) {
            int end = value.indexOf(comma, start);
            if (end == -1) {
                // BLAHn has been found
                end = value.indexOf(rightBracket, start);
                result.add(value.substring(start, end));
                return result;
            }
            result.add(value.substring(start, end));
            start = end + 1;
        }
    }

    // print the command line
    public void println() {
        for (String arg : args) {
            System.out.println(" " + arg);
        }
    }

    // convert to string
    @Override
    public String toString() {
        String result = "CommandLine(";
        boolean firstTime = true;
        for (String arg : args) {
            result += (firstTime ? "" : ",") + arg;
            firstTime = false;
        }
        return result + ")";
    }
}
