/*
Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/*
    Note that this file contains similar functionality to th.h / th_gfx.h from
    the main CorsixTH project. It is reimplemented rather than reused for good
    reasons:
     1) Animations need to be rendered onto a wxWidgets canvas rather than onto
         an SDL or DirectX canvas.
     2) Modifications and experimentation can be performed on this version
         before being implemented on the game copy, resulting in better code
         when the game version is implemented.
     3) Simplicity rather than speed is the aim of this copy, so it will render
         slower than the game copy, but will be easier to understand and make
         changes to.
*/

#ifndef ANIMVIEW_TH_H_
#define ANIMVIEW_TH_H_

#include "config.h"

#include <wx/file.h>
#include <wx/string.h>

#include <array>
#include <cstring>
#include <exception>
#include <memory>
#include <type_traits>
#include <vector>
#include <cstdint>

class wxImage;
class wxSize;

#pragma pack(push)
#pragma pack(1)

struct th_anim_t {
  uint16_t frame;
  uint16_t unknown;
};

struct th_frame_t {
  uint32_t list_index;
  uint8_t width;
  uint8_t height;
  uint16_t flags;
  uint16_t next;
};

struct th_element_t {
  uint16_t table_position;
  uint8_t offx;
  uint8_t offy;
  uint8_t flags;
  uint8_t layerid;
};

struct th_sprite_t {
  uint32_t offset;
  uint8_t width;
  uint8_t height;
};

struct th_colour_t {
  uint8_t r;
  uint8_t g;
  uint8_t b;
};

#pragma pack(pop)

class THLayerMask {
 public:
  THLayerMask() = default;

  inline void set(int iLayer, int iID) {
    if (0 <= iLayer && iLayer < 13 && 0 <= iID && iID < 32)
      m_iMask[iLayer] |= (1ul << iID);
  }

  void clear();

  inline void clear(int iLayer, int iID) {
    if (0 <= iLayer && iLayer < 13 && 0 <= iID && iID < 32)
      m_iMask[iLayer] &= ~(1ul << iID);
  }

  inline bool isSet(int iLayer, int iID) const {
    if (0 <= iLayer && iLayer < 13 && 0 <= iID && iID < 32)
      return (m_iMask[iLayer] & (1ul << iID)) != 0;
    else
      return false;
  }
  inline bool isSet(int iLayer) const {
    if (0 <= iLayer && iLayer < 13)
      for (int iId = 0; iId < 32; ++iId) {
        if ((m_iMask[iLayer] & (1ul << iId)) != 0) return true;
      }
    return false;
  }

 protected:
  uint32_t m_iMask[13]{};
};

class Bitmap {
 public:
  Bitmap();
  ~Bitmap();

  void create(int iWidth, int iHeight);
  void create(int iWidth, int iHeight, const uint8_t* pData);

  inline uint8_t pixel(int iX, int iY) const {
    return m_pData[iY * m_iWidth + iX];
  }
  inline uint8_t& pixel(int iX, int iY) { return m_pData[iY * m_iWidth + iX]; }

  int getWidth() const { return m_iWidth; }
  int getHeight() const { return m_iHeight; }

  void blit(Bitmap& bmpCanvas, int iX, int iY, int iFlags = 0) const;
  void blit(wxImage& imgCanvas, int iX, int iY,
            const unsigned char* pColourTranslate, const th_colour_t* pPalette,
            int iFlags = 0) const;

  bool IsOk() { return m_pData != nullptr; }

 protected:
  int m_iWidth;
  int m_iHeight;
  uint8_t* m_pData;
};

// The original metadata element, with source sprite identity resolved.
// "enabled_by_mask" is NOT pixel visibility: transparent pixels, draw flags
// and overlapping source elements still determine the final image.
struct THFrameSource {
  size_t element_id{};
  size_t sprite_id{};
  uint8_t x{}, y{}, width{}, height{}, layer{}, layer_id{}, draw_flags{};
  bool enabled_by_mask{};
};

class THAnimations {
 public:
  THAnimations();
  ~THAnimations() = default;

  bool loadAnimationFile(const wxString& sFilename) {
    return loadVector(anims, sFilename);
  }

  bool loadFrameFile(const wxString& sFilename);

  bool loadListFile(const wxString& sFilename) {
    return loadVector(elementList, sFilename);
  }

  bool loadElementFile(const wxString& sFilename) {
    return loadVector(elements, sFilename);
  }

  bool loadTableFile(const wxString& sFilename);

  // Commit a new DAT and its decoded-bitmap cache together. A failed read
  // keeps the previously selected data and decoded pixels intact.
  bool loadSpriteFile(const wxString& sFilename);

  bool loadPaletteFile(const wxString& sFilename);

  bool loadGhostFile(const wxString& sFilename, int iIndex);

  // Commit an entirely loaded animation set after all required inputs pass.
  // Swaps only asset content; window-specific options remain on this model.
  void swapLoadedData(THAnimations& other) noexcept;

  size_t markDuplicates();

  size_t getAnimationCount();
  size_t getSpriteCount();
  size_t getFrameCount(size_t iAnimation);
  uint16_t getUnknownField(size_t iAnimation) {
    return anims.at(iAnimation).unknown;
  }
  uint16_t getFrameField(size_t iAnimation) {
    return anims.at(iAnimation).frame;
  }
  th_frame_t* getFrameStruct(size_t iAnimation, size_t iFrame);
  bool isAnimationDuplicate(size_t iAnimation);
  bool doesAnimationIncludeFrame(size_t iAnimation, size_t iFrame);
  void getAnimationMask(size_t iAnimation, THLayerMask& mskLayers);
  void setSpritePath(const wxString& aPath);

  // Read-only: resolve source elements of an actual animation frame, in
  // drawing order. Reject damaged metadata rather than return associations
  // that may have run into the following frame's element list.
  // Failure does not modify 'out'. Does not mutate animation/frame state.
  bool getFrameSources(size_t animation, size_t frame_ordinal,
                       const THLayerMask* active_mask,
                       std::vector<THFrameSource>& out) const;

  Bitmap* getSpriteBitmap(size_t iSprite, bool bComplex = false);
  // The frame-source preview must not index an absent/partial palette.
  bool hasValidPalette() const { return colours.size() == 256; }
  // Render one original VSPR sprite onto a fixed square RGB preview.
  // Nearest-neighbour integer zoom; source index 0xFF is transparent and
  // shows the checkerboard. Outputs remain unchanged when this returns false.
  // This is deliberately wxWidgets-independent so the actual preview pixels
  // can be verified before compiling the dialog.
  bool renderSourcePreview(size_t sprite_id, int side,
                           std::vector<uint8_t>& rgb, int& zoom);
  th_colour_t* getPalette() { return colours.data(); }

  void setGhost(int iFile, int iIndex);
  void drawFrame(wxImage& imgCanvas, size_t iAnimation, size_t iFrame,
                 const THLayerMask* pMask, wxSize& size, int iXOffset = 0,
                 int iYOffset = 0);
  void copySpriteToCanvas(wxString spriteFile, int iSpriteIndex,
                          wxImage& imgCanvas, int iX, int iY, int iFlags = 0);

  static unsigned char* Decompress(unsigned char* pData, size_t& iLength);

 protected:
  // Read into temporary storage first: short reads and malformed records must
  // never leave a half-populated model or read past the file allocation.
  template <class T>
  bool loadVector(std::vector<T>& vector, const wxString& sFilename) {
    static_assert(std::is_trivially_copyable_v<T>, "raw record type must be trivially copyable");
    wxFile file(sFilename);
    if (!file.IsOpened()) return false;

    size_t length = static_cast<size_t>(file.Length());
    constexpr size_t kMaxFileSize = 64u * 1024u * 1024u;
    if (length > kMaxFileSize) return false;
    auto bytes = std::make_unique<unsigned char[]>(length ? length : 1);
    if (length && file.Read(bytes.get(), length) != length) return false;

    if (length >= 4 && std::memcmp(bytes.get(), "RNC\001", 4) == 0) {
      // RNC needs an 18-byte header. Decompress takes ownership of the input.
      if (length < 18) return false;
      try {
        bytes.reset(Decompress(bytes.release(), length));
      } catch (const std::exception&) {
        return false;
      }
      if (!bytes) return false;
    }
    if (length % sizeof(T) != 0) return false;

    std::vector<T> loaded(length / sizeof(T));
    if (length) std::memcpy(loaded.data(), bytes.get(), length);
    vector.swap(loaded);
    return true;
  }

  th_element_t* _getElement(uint32_t iListIndex);

  std::vector<th_anim_t> anims;
  std::vector<th_frame_t> frames;
  std::vector<uint16_t> elementList;
  std::vector<th_element_t> elements;
  std::vector<th_sprite_t> sprites;
  std::vector<Bitmap> spriteBitmaps;
  std::vector<uint8_t> chunks;
  std::vector<th_colour_t> colours;
  std::array<unsigned char, 256 * 256 * 4> ghostMaps{};
  size_t m_iGhostMapOffset{};
  wxString m_sSpritePath;
};

#endif
