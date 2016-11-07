#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Conversion import handlers BusinessmanReporting --> SmallBusiness {4a32c1a3-f1e6-11e1-9a1f-00055d4ef1e7}                                                                   
// 
// This module contains export procedures of conversion event handlers and is intended for exchange rule debugging. After debugging
// it is recommended to copy module text to the clipboard and
// import it in base "Data conversion".
//
// /////////////////////////////////////////////////////////////////////////////
// USED SHORT NAMES VARIABLES (ABBREVIATIONS)
//
//  OCR  - object conversion rule
//  PCR  - object property conversion rule 
//  PGCR - object property group conversion
//  DDR  - data export rule 
//  DCR  - data clearing rule

////////////////////////////////////////////////////////////////////////////////
// DATA PROCESSOR VARIABLES
// It is prohibited to change this section.

Var Parameters;
Var Algorithms;
Var Queries;
Var NodeForExchange;
Var CommonProcedureFunctions;

////////////////////////////////////////////////////////////////////////////////
// CONVERSION HANDLERS (GLOBAL)
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT CONVERSION HANDLERS 
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY CONVERSION HANDLERS 
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY GROUP CONVERSION HANDLERS
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// DATA EXPORT HANDLERS
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// DATA CLEARING HANDLERS 
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// PARAMETER HANDLERS 
// It is allowed to modify the procedure implementation in this section.

////////////////////////////////////////////////////////////////////////////////
// ALGORITHMS
// It is allowed to change this section.
// Also it is allowed to place procedure with algorithms in any section above.

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS 
// It is prohibited to change this section.

// Initializes the variables necessary for debugging
//
// Parameters:
//  Owner - Data processor InfobaseObjectConversion
//
Procedure ConnectProcessingForDebugging(Owner) Export

	Parameters            	   = Owner.Parameters;
	CommonProcedureFunctions	 = Owner;
	Queries              	    = Owner.Queries;
	NodeForExchange		 	      = Owner.NodeForExchange;

EndProcedure

#EndIf