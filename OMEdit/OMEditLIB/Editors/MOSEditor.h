/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES RECIPIENT'S ACCEPTANCE
 * OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from OSMC, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */
/*
 * @author adrian.pop@liu.se
 */
#ifndef MOSEDITOR_H
#define MOSEDITOR_H

#include "Editors/BaseEditor.h"

#include <QRegExp>
#include <QSyntaxHighlighter>

class MOSEditorPage;
class MOSEditor : public BaseEditor
{
  Q_OBJECT
public:
  MOSEditor(QWidget *pParent);
  void setPlainText(const QString &text);
  virtual void popUpCompleter() override;
  static QList<CompleterItem> getCodeSnippets();
private slots:
  virtual void showContextMenu(QPoint point) override;
public slots:
  virtual void contentsHasChanged(int position, int charsRemoved, int charsAdded) override;
  virtual void toggleCommentSelection() override;
};

class MOSHighlighter : public QSyntaxHighlighter
{
  Q_OBJECT
public:
  MOSHighlighter(MOSEditorPage *pMOSEditorPage, QPlainTextEdit *pPlainTextEdit = 0);
  void initializeSettings();
  void highlightMultiLine(const QString &text);
  static QStringList getKeywords();
  static QStringList getTypes();
protected:
  virtual void highlightBlock(const QString &text) override;
private:
  MOSEditorPage *mpMOSEditorPage;
  QPlainTextEdit *mpPlainTextEdit;
  struct HighlightingRule
  {
    QRegExp mPattern;
    QTextCharFormat mFormat;
  };
  QVector<HighlightingRule> mHighlightingRules;
  QTextCharFormat mTextFormat;
  QTextCharFormat mKeywordFormat;
  QTextCharFormat mTypeFormat;
  QTextCharFormat mQuotationFormat;
  QTextCharFormat mSingleLineCommentFormat;
  QTextCharFormat mMultiLineCommentFormat;
  QTextCharFormat mNumberFormat;
public slots:
  void settingsChanged();
};

#endif // MOSEDITOR_H
