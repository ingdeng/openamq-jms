<?xml version='1.0'?> 
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:amq="http://amq.org"> 

<!-- this class contains the templates for generating java source code for a given framing model -->
<xsl:import href="utils.xsl"/>
<xsl:output method="text" indent="yes" name="textFormat"/> 

<xsl:param name="registry_name"/>

<xsl:template match="/"> 
    <xsl:apply-templates mode="generate-multi" select="frames"/>
    <xsl:apply-templates mode="generate-registry" select="frames"/>
</xsl:template>

<!-- processes all frames outputting the classes in a single stream -->
<!-- (useful for debugging etc) -->
<xsl:template match="frame" mode="generate-single"> 
    <xsl:call-template name="generate-class">
        <xsl:with-param name="f" select="."/>
    </xsl:call-template>
</xsl:template>

<!-- generates seperate file for each class/frame -->
<xsl:template match="frame" mode="generate-multi"> 
    <xsl:variable name="uri" select="concat(@name, '.java')"/> 
    wrote <xsl:value-of select="$uri"/> 
    <xsl:result-document href="{$uri}" format="textFormat"> 
    <xsl:call-template name="generate-class">
        <xsl:with-param name="f" select="."/>
    </xsl:call-template>
    </xsl:result-document> 
</xsl:template> 

<!-- main class generation template -->
<xsl:template name="generate-class"> 
    <xsl:param name="f"/>
package org.openamq.framing;

import org.apache.mina.common.ByteBuffer;

/**
 * This class is autogenerated, do not modify. [From <xsl:value-of select="$f/parent::frames/@protocol"/>]
 */
public class <xsl:value-of select="$f/@name"/> extends AMQMethodBody implements EncodableAMQDataBlock
{ 
    public static final int CLASS_ID = <xsl:value-of select="$f/@class-id"/>; 	
    public static final int METHOD_ID = <xsl:value-of select="$f/@method-id"/>; 	

    <xsl:for-each select="$f/field"> 
        <xsl:text>public </xsl:text><xsl:value-of select="@java-type"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="@name"/>;    
    </xsl:for-each> 

    protected int getClazz()
    {
        return <xsl:value-of select="$f/@class-id"/>;
    }
   
    protected int getMethod()
    {
        return <xsl:value-of select="$f/@method-id"/>;
    }

    protected int getBodySize()
    {
        <xsl:choose> 
        <xsl:when test="$f/field">
        return
        <xsl:for-each select="$f/field">
            <xsl:if test="position() != 1">+
            </xsl:if>
            <xsl:value-of select="amq:field-length(.)"/>
        </xsl:for-each>		 
        ;
        </xsl:when>
        <xsl:otherwise>return 0;</xsl:otherwise>
        </xsl:choose> 
    }

    protected void writeMethodPayload(ByteBuffer buffer)
    {
        <xsl:for-each select="$f/field">
            <xsl:if test="@type != 'bit'">
                <xsl:value-of select="amq:encoder(.)"/>;
            </xsl:if>
            <xsl:if test="@type = 'bit' and @boolean-index = 1">
                <xsl:text>EncodingUtils.writeBooleans(buffer, new boolean[]{</xsl:text>
                <xsl:value-of select="$f/field[@type='bit']/@name" separator=", "/>});
            </xsl:if>
        </xsl:for-each>		 
    }

    public void populateMethodBodyFromBuffer(ByteBuffer buffer) throws AMQFrameDecodingException
    {
        <xsl:for-each select="$f/field">
            <xsl:value-of select="amq:decoder(.)"/>;
        </xsl:for-each>		 
    }

    public String toString()
    {
        StringBuffer buf = new StringBuffer(super.toString());
        <xsl:for-each select="$f/field">
            <xsl:text>buf.append(" </xsl:text><xsl:value-of select="@name"/>: ").append(<xsl:value-of select="@name"/>);
        </xsl:for-each> 
        return buf.toString();
    }

    public static AMQFrame createAMQFrame(int frameChannelId<xsl:if test="$f/field">, </xsl:if><xsl:value-of select="$f/field/concat(@java-type, ' ', @name)" separator=", "/>)
    {
        <xsl:value-of select="@name"/> bodyFrame = new <xsl:value-of select="@name"/>();
        <xsl:for-each select="$f/field">
            <xsl:value-of select="concat('bodyFrame.', @name, ' = ', @name)"/>;
        </xsl:for-each>		 
        AMQFrame frame = new AMQFrame();
        frame.channel = frameChannelId;
        frame.bodyFrame = bodyFrame;
        return frame;
    }
} 
</xsl:template> 

<xsl:template match="/" mode="generate-registry">
     <xsl:text>Matching root for registry mode!</xsl:text>
     <xsl:value-of select="."/> 
     <xsl:apply-templates select="frames" mode="generate-registry"/>
</xsl:template>

<xsl:template match="registries" mode="generate-registry">
Wrote MethodBodyDecoderRegistry.java
    <xsl:result-document href="MethodBodyDecoderRegistry.java" format="textFormat">package org.openamq.framing;

import java.util.Map;
import java.util.HashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.openamq.AMQException;

/**
 * This class is autogenerated, do not modify.
 */
public final class MethodBodyDecoderRegistry
{
    private static final Logger _log = LoggerFactory.getLogger(MethodBodyDecoderRegistry.class);

    private static final Map _classMethodProductToMethodBodyMap = new HashMap();

    static
    {
        <xsl:for-each select="registry">
            <xsl:value-of select="concat(@name, '.register(_classMethodProductToMethodBodyMap)')"/>;         
        </xsl:for-each>
    }

    public static AMQMethodBody get(int clazz, int method) throws AMQFrameDecodingException
    {
	Class bodyClass = (Class) _classMethodProductToMethodBodyMap.get(new Integer(clazz * 1000 + method));
	if (bodyClass != null)
	{
	    try
	    {
	        return (AMQMethodBody) bodyClass.newInstance();
	    }
	    catch (Exception e)
	    {
	    	throw new AMQFrameDecodingException(_log, "Unable to instantiate body class for class " + clazz + " and method " + method + ": " + e, e);
	    }
	}
	else
	{
	    throw new AMQFrameDecodingException(_log, "Unable to find a suitable decoder for class " + clazz + " and method " + method);
	}    
    }
}
</xsl:result-document>
</xsl:template>

<xsl:template match="frames" mode="list-registry">	
    <xsl:if test="$registry_name">

    <xsl:variable name="file" select="concat($registry_name, '.java')"/> 
    wrote <xsl:value-of select="$file"/> 
    <xsl:result-document href="{$file}" format="textFormat">package org.openamq.framing;

import java.util.Map;

/**
 * This class is autogenerated, do not modify. [From <xsl:value-of select="@protocol"/>]
 */
class <xsl:value-of select="$registry_name"/>
{
    static void register(Map map)
    {
        <xsl:for-each select="frame">
            <xsl:text>map.put(new Integer(</xsl:text>
            <xsl:value-of select="@class-id"/>         
	    <xsl:text> * 1000 + </xsl:text> 
            <xsl:value-of select="@method-id"/>         
	    <xsl:text>), </xsl:text> 
            <xsl:value-of select="concat(@name, '.class')"/>);         
        </xsl:for-each>
    }
}
    </xsl:result-document>

    </xsl:if>
</xsl:template>

</xsl:stylesheet>
