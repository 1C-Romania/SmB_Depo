
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not Parameters.Property("Order") Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='It is possible to call report only from the document ""Customer order"".';ru='Вызов отчета возможен только из документа ""Заказ покупателя""!'");
		Message.Message();
		
		Cancel = True;
		Return;
		
	EndIf;
	
	DCSParameters = Report.SettingsComposer.Settings.DataParameters;
	DCSParameter = DCSParameters.Items.Find("Order");
	
	If DCSParameter <> Undefined Then
		DCSParameters.SetParameterValue("Order", Parameters.Order);
	EndIf;
	
	ComposeResult();
	
EndProcedure // OnCreateAtServer()
// 
