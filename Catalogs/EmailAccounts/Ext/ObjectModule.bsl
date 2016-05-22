#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Initializes a new account with default values.
//
Procedure FillObjectByDefaultValues() Export
	
	UserName = NStr("en = '1C:Enterprise'");
	UseForReceiving = False;
	UseForSending = False;
	LeaveMessageCopiesOnServer = False;
	ServerEmailStoragePeriod = 0;
	Timeout = 30;
	IncomingMailServerPort = 110;
	OutgoingMailServerPort = 25;
	IncomingMailProtocol = "POP";
	
EndProcedure

#EndRegion

#Region EventsHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	FillObjectByDefaultValues();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not UseForSending AND Not UseForReceiving Then
		CheckedAttributes.Clear();
		CheckedAttributes.Add("Description");
		Return;
	EndIf;
	
	NoncheckableAttributeArray = New Array;
	
	If Not UseForSending Then
		NoncheckableAttributeArray.Add("OutgoingMailServer");
	EndIf;
	
	If Not UseForReceiving Then
		NoncheckableAttributeArray.Add("IncomingMailServer");
	EndIf;
		
	If Not IsBlankString(EmailAddress) AND Not CommonUseClientServer.EmailAddressMeetsRequirements(EmailAddress, True) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Postal address is filled incorrectly.'"), ThisObject, "EmailAddress");
		NoncheckableAttributeArray.Add("EmailAddress");
		Cancel = True;
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

#EndRegion

#EndIf
