﻿////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// The procedure places pick-up results in the storage.
//
Procedure WriteGLAccountsToStorage() 
	
	//GLAccountsInStorage = GLAccounts.Unload(, "GLAccount");
	PutToTempStorage(GLAccounts.Unload(), GLAccountsInStorageAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - command handler OK.
//
Procedure OK(Command)
	
	WriteGLAccountsToStorage();
	Close(DialogReturnCode.OK);

EndProcedure // Ok()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountsInStorageAddress = Parameters.GLAccountsInStorageAddress;
	GLAccounts.Load(GetFromTempStorage(GLAccountsInStorageAddress));
	
EndProcedure // OnCreateAtServer()
// 



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
