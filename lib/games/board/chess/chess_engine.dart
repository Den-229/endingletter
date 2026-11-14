import 'dart:math' as math;

enum PieceColor { white, black }

enum PieceType { pawn, knight, bishop, rook, queen, king }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({
    required this.type,
    required this.color,
    this.hasMoved = false,
  });

  ChessPiece copy() => ChessPiece(type: type, color: color, hasMoved: hasMoved);

  int get value {
    switch (type) {
      case PieceType.pawn:
        return 10;
      case PieceType.knight:
      case PieceType.bishop:
        return 30;
      case PieceType.rook:
        return 50;
      case PieceType.queen:
        return 90;
      case PieceType.king:
        return 1000;
    }
  }

  String get symbol {
    switch (type) {
      case PieceType.pawn:
        return color == PieceColor.white ? '♙' : '♟';
      case PieceType.knight:
        return color == PieceColor.white ? '♘' : '♞';
      case PieceType.bishop:
        return color == PieceColor.white ? '♗' : '♝';
      case PieceType.rook:
        return color == PieceColor.white ? '♖' : '♜';
      case PieceType.queen:
        return color == PieceColor.white ? '♕' : '♛';
      case PieceType.king:
        return color == PieceColor.white ? '♔' : '♚';
    }
  }
}

class ChessMove {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  ChessMove(this.fromRow, this.fromCol, this.toRow, this.toCol);
}

class ChessSnapshot {
  final List<List<ChessPiece?>> board;
  final PieceColor turn;
  final List<ChessPiece> capturedWhite;
  final List<ChessPiece> capturedBlack;
  final List<String> history;

  ChessSnapshot({
    required this.board,
    required this.turn,
    required this.capturedWhite,
    required this.capturedBlack,
    required this.history,
  });

  static ChessSnapshot from(ChessGame game) {
    return ChessSnapshot(
      board: List.generate(8, (r) => List.generate(8, (c) => game.board[r][c]?.copy())),
      turn: game.currentTurn,
      capturedWhite: game.capturedByWhite.map((p) => p.copy()).toList(),
      capturedBlack: game.capturedByBlack.map((p) => p.copy()).toList(),
      history: List.from(game.moveHistory),
    );
  }
}

class ChessGame {
  late List<List<ChessPiece?>> board;
  PieceColor currentTurn = PieceColor.white;
  List<ChessPiece> capturedByWhite = [];
  List<ChessPiece> capturedByBlack = [];
  List<String> moveHistory = [];
  final List<ChessSnapshot> _undoStack = [];
  bool isCheck = false;
  bool isCheckmate = false;

  ChessGame() {
    reset();
  }

  bool get canUndo => _undoStack.isNotEmpty;

  void reset() {
    _undoStack.clear();
    moveHistory.clear();
    currentTurn = PieceColor.white;
    capturedByWhite = [];
    capturedByBlack = [];
    isCheck = false;
    isCheckmate = false;

    board = List.generate(8, (_) => List<ChessPiece?>.filled(8, null));

    // Pions
    for (int col = 0; col < 8; col++) {
      board[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
      board[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
    }

    // Pièces majeures noires
    board[0][0] = ChessPiece(type: PieceType.rook, color: PieceColor.black);
    board[0][1] = ChessPiece(type: PieceType.knight, color: PieceColor.black);
    board[0][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);
    board[0][3] = ChessPiece(type: PieceType.queen, color: PieceColor.black);
    board[0][4] = ChessPiece(type: PieceType.king, color: PieceColor.black);
    board[0][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);
    board[0][6] = ChessPiece(type: PieceType.knight, color: PieceColor.black);
    board[0][7] = ChessPiece(type: PieceType.rook, color: PieceColor.black);

    // Pièces majeures blanches
    board[7][0] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
    board[7][1] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    board[7][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    board[7][3] = ChessPiece(type: PieceType.queen, color: PieceColor.white);
    board[7][4] = ChessPiece(type: PieceType.king, color: PieceColor.white);
    board[7][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    board[7][6] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    board[7][7] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
  }

  bool undoLastMove() {
    if (!canUndo) return false;
    final snap = _undoStack.removeLast();
    board = List.generate(8, (r) => List.generate(8, (c) => snap.board[r][c]?.copy()));
    currentTurn = snap.turn;
    capturedByWhite = snap.capturedWhite.map((p) => p.copy()).toList();
    capturedByBlack = snap.capturedBlack.map((p) => p.copy()).toList();
    moveHistory = List.from(snap.history);
    return true;
  }

  int get materialAdvantage {
    int whiteTotal = capturedByWhite.fold(0, (sum, p) => sum + p.value);
    int blackTotal = capturedByBlack.fold(0, (sum, p) => sum + p.value);
    return (whiteTotal - blackTotal) ~/ 10;
  }

  bool isInside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<ChessMove> getLegalMoves(int r, int c) {
    final piece = board[r][c];
    if (piece == null) return [];

    List<ChessMove> moves = [];

    void checkRay(int dr, int dc) {
      int nr = r + dr;
      int nc = c + dc;
      while (isInside(nr, nc)) {
        final dest = board[nr][nc];
        if (dest == null) {
          moves.add(ChessMove(r, c, nr, nc));
        } else {
          if (dest.color != piece.color) {
            moves.add(ChessMove(r, c, nr, nc));
          }
          break;
        }
        nr += dr;
        nc += dc;
      }
    }

    switch (piece.type) {
      case PieceType.pawn:
        final dir = piece.color == PieceColor.white ? -1 : 1;
        final startRow = piece.color == PieceColor.white ? 6 : 1;

        // Avance 1 case
        if (isInside(r + dir, c) && board[r + dir][c] == null) {
          moves.add(ChessMove(r, c, r + dir, c));
          // Avance 2 cases depuis le départ
          if (r == startRow && board[r + 2 * dir][c] == null) {
            moves.add(ChessMove(r, c, r + 2 * dir, c));
          }
        }

        // Prise diagonale
        for (final dc in [-1, 1]) {
          final nr = r + dir;
          final nc = c + dc;
          if (isInside(nr, nc) && board[nr][nc] != null && board[nr][nc]!.color != piece.color) {
            moves.add(ChessMove(r, c, nr, nc));
          }
        }
        break;

      case PieceType.knight:
        const deltas = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1]
        ];
        for (final d in deltas) {
          final nr = r + d[0];
          final nc = c + d[1];
          if (isInside(nr, nc)) {
            final dest = board[nr][nc];
            if (dest == null || dest.color != piece.color) {
              moves.add(ChessMove(r, c, nr, nc));
            }
          }
        }
        break;

      case PieceType.bishop:
        checkRay(-1, -1);
        checkRay(-1, 1);
        checkRay(1, -1);
        checkRay(1, 1);
        break;

      case PieceType.rook:
        checkRay(-1, 0);
        checkRay(1, 0);
        checkRay(0, -1);
        checkRay(0, 1);
        break;

      case PieceType.queen:
        checkRay(-1, -1);
        checkRay(-1, 1);
        checkRay(1, -1);
        checkRay(1, 1);
        checkRay(-1, 0);
        checkRay(1, 0);
        checkRay(0, -1);
        checkRay(0, 1);
        break;

      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (isInside(nr, nc)) {
              final dest = board[nr][nc];
              if (dest == null || dest.color != piece.color) {
                moves.add(ChessMove(r, c, nr, nc));
              }
            }
          }
        }
        break;
    }

    return moves;
  }

  String _formatNotation(ChessMove move, ChessPiece piece, ChessPiece? target) {
    const cols = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final toSquare = '${cols[move.toCol]}${8 - move.toRow}';
    String pieceChar = '';
    switch (piece.type) {
      case PieceType.pawn: pieceChar = target != null ? cols[move.fromCol] : ''; break;
      case PieceType.knight: pieceChar = 'N'; break;
      case PieceType.bishop: pieceChar = 'B'; break;
      case PieceType.rook: pieceChar = 'R'; break;
      case PieceType.queen: pieceChar = 'Q'; break;
      case PieceType.king: pieceChar = 'K'; break;
    }
    final captureChar = target != null ? 'x' : '';
    return '$pieceChar$captureChar$toSquare';
  }

  bool makeMove(ChessMove move) {
    final piece = board[move.fromRow][move.fromCol];
    if (piece == null || piece.color != currentTurn) return false;

    _undoStack.add(ChessSnapshot.from(this));
    if (_undoStack.length > 30) _undoStack.removeAt(0);

    final target = board[move.toRow][move.toCol];
    if (target != null) {
      if (currentTurn == PieceColor.white) {
        capturedByWhite.add(target);
      } else {
        capturedByBlack.add(target);
      }
    }

    // Notation
    final notation = _formatNotation(move, piece, target);
    if (currentTurn == PieceColor.white) {
      final moveNum = (moveHistory.length ~/ 2) + 1;
      moveHistory.add('$moveNum. $notation');
    } else {
      if (moveHistory.isNotEmpty) {
        moveHistory[moveHistory.length - 1] += ' $notation';
      } else {
        moveHistory.add('1... $notation');
      }
    }

    board[move.toRow][move.toCol] = piece;
    board[move.fromRow][move.fromCol] = null;
    piece.hasMoved = true;

    // Promotion automatique du pion en Dame s'il atteint la dernière rangée
    if (piece.type == PieceType.pawn) {
      if ((piece.color == PieceColor.white && move.toRow == 0) ||
          (piece.color == PieceColor.black && move.toRow == 7)) {
        board[move.toRow][move.toCol] = ChessPiece(
          type: PieceType.queen,
          color: piece.color,
          hasMoved: true,
        );
      }
    }

    // Changement de tour
    currentTurn = currentTurn == PieceColor.white ? PieceColor.black : PieceColor.white;
    return true;
  }

  /// IA Tactique simple (Minimax heuristique 1 coup)
  ChessMove? computeBestAiMove(PieceColor aiColor) {
    List<ChessMove> allMoves = [];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.color == aiColor) {
          allMoves.addAll(getLegalMoves(r, c));
        }
      }
    }

    if (allMoves.isEmpty) return null;

    ChessMove? bestMove;
    int bestScore = -99999;
    final rnd = math.Random();
    allMoves.shuffle(rnd);

    for (final move in allMoves) {
      int score = 0;
      final target = board[move.toRow][move.toCol];
      if (target != null) {
        score += target.value * 10;
      }
      // Avance vers le centre
      final centerDist = (3.5 - move.toRow).abs() + (3.5 - move.toCol).abs();
      score -= (centerDist * 2).toInt();

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? allMoves.first;
  }
}
