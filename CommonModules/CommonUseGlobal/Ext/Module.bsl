////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Prompts whether the action that results in loss of changes should be continued
//
Procedure ConfirmFormClosingNow() Export
	
	CommonUseClient.ConfirmFormClosing();
	
EndProcedure

// Prompts whether the action that results in closing the form should be continued.
//
Procedure ConfirmArbitraryFormClosingNow() Export
	
	CommonUseClient.ConfirmArbitraryFormClosing();
	
EndProcedure

#EndRegion
