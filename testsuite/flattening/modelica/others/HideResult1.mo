// name: HideResult1
// keywords:
// status: correct
//
//

model A
  Real x;
  Real y annotation(HideResult = false);
end A;

model B
  extends A;
  A a1 annotation(HideResult = true);
  A a2;
  Real z;
end B;

model HideResult1
  B b1 annotation(HideResult = false);
  parameter Boolean hide = true;
  B b2 annotation(HideResult = hide);
  annotation(__OpenModelica_commandLineOptions="-d=newInst --showAnnotations");
end HideResult1;

// Result:
// class HideResult1
//   Real b1.x annotation(HideResult = false);
//   Real b1.y annotation(HideResult = false);
//   Real b1.a1.x annotation(HideResult = true);
//   Real b1.a1.y annotation(HideResult = false);
//   Real b1.a2.x annotation(HideResult = false);
//   Real b1.a2.y annotation(HideResult = false);
//   Real b1.z annotation(HideResult = false);
//   parameter Boolean hide = true;
//   Real b2.x annotation(HideResult = true);
//   Real b2.y annotation(HideResult = false);
//   Real b2.a1.x annotation(HideResult = true);
//   Real b2.a1.y annotation(HideResult = false);
//   Real b2.a2.x annotation(HideResult = true);
//   Real b2.a2.y annotation(HideResult = false);
//   Real b2.z annotation(HideResult = true);
//   annotation(__OpenModelica_commandLineOptions = "-d=newInst --showAnnotations");
// end HideResult1;
// endResult
