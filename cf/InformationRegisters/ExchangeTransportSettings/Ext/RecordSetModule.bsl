#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// Records set modification is prohibited for not shared nodes in separation mode.
	DataExchangeServer.RunControlRecordsUndividedData(Filter.Node.Value);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each SetRow IN ThisObject Do
		
		// Reset password value if the flag of storing the password in IB is not enabled.
		If Not SetRow.WSRememberPassword Then
			
			SetRow.WSPassword = "";
			
		EndIf;
		
		// For string parameters we delete insignificant characters (spaces) on the left and on the right.
		TrimAllFieldValue(SetRow, "COMInfobaseNameAtServer1CEnterprise");
		TrimAllFieldValue(SetRow, "COMUserName");
		TrimAllFieldValue(SetRow, "COMServerName1CEnterprise");
		TrimAllFieldValue(SetRow, "COMInfobaseDirectory");
		TrimAllFieldValue(SetRow, "COMUserPassword");
		TrimAllFieldValue(SetRow, "FILEInformationExchangeDirectory");
		TrimAllFieldValue(SetRow, "FTPConnectionPassword");
		TrimAllFieldValue(SetRow, "FTPConnectionUser");
		TrimAllFieldValue(SetRow, "FTPConnectionPath");
		TrimAllFieldValue(SetRow, "WSURLWebService");
		TrimAllFieldValue(SetRow, "WSUserName");
		TrimAllFieldValue(SetRow, "WSPassword");
		TrimAllFieldValue(SetRow, "ExchangeMessageArchivePassword");
		
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Update platform cache to read actual
	// procedure exchange message transport settings DataExchangeReUse.GetExchangeSettingStructure.
	RefreshReusableValues();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure TrimAllFieldValue(Record, Val Field)
	
	Record[Field] = TrimAll(Record[Field]);
	
EndProcedure

#EndRegion

#EndIf
