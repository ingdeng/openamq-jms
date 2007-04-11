/**
 * AMQTest
 * Copyright (C) 2001-2005, J.P. Morgan Chase & Co. Incorporated.
 * all Rights Reserved.
 * The information contained herein is proprietary and confidential, and may 
 * not be duplicated or redistributed in any form without express written
 * consent of J.P. MorganChase & Co. Incorporated.
 * 
 * Created on Feb 10, 2006
 */
package org.openamq.multiconsumer;

import java.io.ByteArrayOutputStream;
import java.util.zip.Deflater;
import java.util.zip.Inflater;

import javax.jms.Connection;
import javax.jms.ExceptionListener;
import javax.jms.JMSException;
import javax.jms.Message;
import javax.jms.MessageConsumer;
import javax.jms.MessageListener;
import javax.jms.MessageProducer;
import javax.jms.Session;
import javax.jms.TextMessage;
import javax.jms.Topic;

import junit.framework.TestCase;

import org.apache.commons.codec.binary.Base64;
import org.openamq.client.AMQConnectionFactory;
import org.openamq.client.AMQConnection;
import org.openamq.client.AMQTopic;

/**
 * Test AMQ.
 */
public class AMQTest extends TestCase implements ExceptionListener
{

    private final static String COMPRESSION_PROPNAME = "_MSGAPI_COMP";
    private final static String UTF8 = "UTF-8";
    private static final String SUBJECT = "test.amq";
    private static final String DUMMYCONTENT = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    private static final String HUGECONTENT;

    private Connection connect = null;
    private Session pubSession = null;
    private Session subSession = null;
    private Topic topic = null;

    static
    {
        StringBuilder sb = new StringBuilder(DUMMYCONTENT.length() * 115);
        for (int i = 0; i < 100; i++)
        {
            sb.append(DUMMYCONTENT);
        }
        HUGECONTENT = sb.toString();
    }

    private void setup() throws Exception
    {
        connect = new AMQConnection("localhost", 5672, "guest", "guest", "client1", "/");
        connect.setExceptionListener(this);
        pubSession = connect.createSession(false, javax.jms.Session.AUTO_ACKNOWLEDGE);
        subSession = connect.createSession(false, javax.jms.Session.AUTO_ACKNOWLEDGE);
        topic = new AMQTopic(SUBJECT);

        connect.start();
    }

    public void testMultipleListeners() throws Exception
    {
        setup();
        try
        {
            // Create 5 listeners
            MsgHandler[] listeners = new MsgHandler[5];
            for (int i = 0; i < listeners.length; i++)
            {
                listeners[i] = new MsgHandler();
                MessageConsumer subscriber = subSession.createConsumer(topic);
                subscriber.setMessageListener(listeners[i]);
            }
            MessageProducer publisher = pubSession.createProducer(topic);
            // Send a single message
            TextMessage msg = pubSession.createTextMessage();
            msg.setText(DUMMYCONTENT);
            publisher.send(msg);
            Thread.sleep(5000);
            // Check listeners to ensure they all got it
            for (int i = 0; i < listeners.length; i++)
            {
                if (listeners[i].isGotIt())
                {
                    System.out.println("Got callback for listener " + i);
                }
                else
                {
                    TestCase.fail("Listener " + i + " did not get callback");
                }
            }
        }
        catch (Throwable e)
        {
            System.err.println("Error: " + e);
            e.printStackTrace(System.err);
        }
        finally
        {
            close();
        }
    }

    public void testCompression() throws Exception
    {
        setup();
        String comp = this.compressString(HUGECONTENT);
        try
        {
            MsgHandler listener = new MsgHandler();
            MessageConsumer subscriber = subSession.createConsumer(topic);
            subscriber.setMessageListener(listener);
            MessageProducer publisher = pubSession.createProducer(topic);

            // Send a single message
            TextMessage msg = pubSession.createTextMessage();
            // Set the compressed text
            msg.setText(comp);
            msg.setBooleanProperty(COMPRESSION_PROPNAME, true);
            publisher.send(msg);
            Thread.sleep(1000);
            // Check listeners to ensure we got it
            if (listener.isGotIt())
            {
                System.out.println("Got callback for listener");
            }
            else
            {
                TestCase.fail("Listener did not get callback");
            }
        }
        finally
        {
            close();
        }
    }

    private void close() throws Exception
    {
        if (connect != null)
        {
            connect.close();
        }
    }

    private class MsgHandler implements MessageListener
    {
        private boolean gotIt = false;

        public void onMessage(Message msg)
        {
            try
            {
                TextMessage textMessage = (TextMessage) msg;
                String string = textMessage.getText();
                if (string != null && string.length() > 0)
                {
                    gotIt = true;
                }
                if (textMessage.getBooleanProperty(COMPRESSION_PROPNAME))
                {
                    string = inflateString(string);
                } 
                System.out.println("Got callback of size " + (string==null?0:string.length()));
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }

        public boolean isGotIt()
        {
            return this.gotIt;
        }
    }

    private String compressString(String string) throws Exception
    {
        long start = System.currentTimeMillis();
        byte[] input = string.getBytes();
        Deflater compressor = new Deflater(Deflater.BEST_COMPRESSION);
        compressor.setInput(input);
        compressor.finish();

        // Get byte array from output of compressor
        ByteArrayOutputStream baos = new ByteArrayOutputStream(input.length);
        byte[] buf = new byte[1024];
        while (!compressor.finished())
        {
            int cnt = compressor.deflate(buf);
            baos.write(buf, 0, cnt);
        }
        baos.close();
        byte[] output = baos.toByteArray();

        // Convert byte array into String
        byte[] base64 = Base64.encodeBase64(output);
        String sComp = new String(base64, UTF8);

        long diff = System.currentTimeMillis() - start;
        System.out.println("Compressed text from " + input.length + " to "
                + sComp.getBytes().length + " in " + diff + " ms");
        System.out.println("Compressed text = '" + sComp + "'");

        return sComp;
    }

    private String inflateString(String string) throws Exception
    {
        byte[] input = string.getBytes();

        // First convert Base64 string back to binary array
        byte[] bytes = Base64.decodeBase64(input);

        // Set string as input data for decompressor
        Inflater decompressor = new Inflater();
        decompressor.setInput(bytes);

        // Decompress the data
        ByteArrayOutputStream bos = new ByteArrayOutputStream(input.length);
        byte[] buf = new byte[1024];
        while (!decompressor.finished())
        {
            int count = decompressor.inflate(buf);
            bos.write(buf, 0, count);
        }
        bos.close();
        byte[] output = bos.toByteArray();

        // Get the decompressed data
        return new String(output, UTF8);
    }

    /**
     * @see javax.jms.ExceptionListener#onException(javax.jms.JMSException)
     */
    public void onException(JMSException e)
    {
        System.err.println(e.getMessage());
        e.printStackTrace(System.err);
    }


}