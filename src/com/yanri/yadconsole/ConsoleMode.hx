package com.yanri.yadconsole;

/**
 * The Console execution mode.
 * @author Yanrishatum
 */
enum ConsoleMode
{

  /**
   * Hybrid mode tries to execute input as command, and only then executes it as script.
   */
  Hybrid;
  /**
   * Restricted Commands mode executes only commands, and not uses scripts.
   */
  Commands;
  /**
   * Script mode do not uses defined commands and always executes input as script.
   */
  Scripts;
  
}