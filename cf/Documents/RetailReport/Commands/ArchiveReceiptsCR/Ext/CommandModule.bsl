&AtServer
Procedure RunReceiptsBackupAtServer(CommandParameter)

	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	RetailReport.Ref
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	RetailReport.Ref IN (&CommandParameter)
	|	AND RetailReport.Posted
	|	AND RetailReport.CashCRSessionStatus = &CashCRSessionStatus
	|	AND RetailReport.CashCR.CashCRType = &CashCRTypeFiscalRegister";
	
	Query.SetParameter("CommandParameter", CommandParameter);
	Query.SetParameter("CashCRSessionStatus", Enums.CashCRSessionStatuses.Closed);
	Query.SetParameter("CashCRTypeFiscalRegister", Enums.CashCRTypes.FiscalRegister);

	Selection = Query.Execute().Select();
	While Selection.Next() Do
	
		ReportAboutRetailSalesObject = Selection.Ref.GetObject();
		If ReportAboutRetailSalesObject.CashCRSessionStatus = Enums.CashCRSessionStatuses.Closed Then
			
			ErrorDescription = "";
			Documents.RetailReport.RunReceiptsBackup(ReportAboutRetailSalesObject, ErrorDescription);
			
			If ValueIsFilled(ErrorDescription) Then
				
				Message = New UserMessage;
				Message.Text = ErrorDescription;
				Message.Message();
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
EndProcedure // RunReceiptsBackupAtServer()

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RunReceiptsBackupAtServer(CommandParameter);
	
	Notify("RefreshFormsAfterClosingCashCRSession");
	
	ShowUserNotification(NStr("en=""Cash register receipts' archiving completed"";ru='Архивация чеков ККМ выполнена'"));
	
EndProcedure // CommandProcessing()
