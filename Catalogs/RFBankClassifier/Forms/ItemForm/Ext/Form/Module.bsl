
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	Items.PagesActivityDiscontinued.Visible = Object.ActivityDiscontinued Or Users.InfobaseUserWithFullAccess();
	Items.PagesActivityDiscontinued.CurrentPage = ?(Users.InfobaseUserWithFullAccess(),
		Items.PageCheckboxActivityDiscontinued, Items.PageLabelActivityDiscontinued);
		
	If Object.ActivityDiscontinued Then
		WindowOptionsKey = "ActivityDiscontinued";
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CommonUse.SubsystemExists("ServiceTechnology.SaaS.DataExchangeSaaS") Then
		
		ModuleWorkOffline = CommonUse.CommonModule("OfflineWork");
		ModuleWorkOffline.ObjectOnReadAtServer(CurrentObject, ThisObject.ReadOnly);
		
	EndIf;
	
EndProcedure

#EndRegion



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
